import 'dart:async';
import 'dart:html';
import 'dart:convert' as convert;

import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:archive/archive.dart' as archive;
import 'package:intl/intl.dart' as intl;

final identifier = new auth.ClientId(
    '99747971048-mqnearp1pli825cm3c8ce4hm1i238cgt.apps.googleusercontent.com',
    null);

final scopes = [youtube.YoutubeApi.YoutubeScope];

youtube.YoutubeApi api;
List<youtube.Playlist> allPlaylists;
String channelTitle; // name of user

archive.Archive oldZipFile = null;

/** Handles authorization of YouTube user. */
Future authorizedClient(ButtonElement authorizeButton, auth.ClientId id,
    scopes) {
  return auth.createImplicitBrowserFlow(id, scopes)
      .then((auth.BrowserOAuth2Flow flow) {
    return flow.clientViaUserConsent(immediate: true).catchError((_) {
      authorizeButton.text = 'Authorize';
      return authorizeButton.onClick.first.then((_) {
        return flow.clientViaUserConsent(immediate: false);
      });
    }, test: (error) => error is auth.UserConsentException);
  });
}

main() {
  ButtonElement authorizeButton = querySelector('#authorize_button');
  ButtonElement downloadButton = querySelector('#download_button');

  // Put callback on input file
  querySelector('#input_file').onChange.listen((_) => userUploadedOldZipFile());

  authorizedClient(authorizeButton, identifier, scopes).then((client) {
    // User authorized

    authorizeButton.disabled = true;
    authorizeButton.text = 'You are authorized';
    downloadButton.disabled = false;

    // Create new api
    api = new youtube.YoutubeApi(client);

    // Retrieve all playlists from the YouTube api
    receivedPlaylists().then((playlists) {
      allPlaylists = playlists;
      displayPlaylists(playlists);

      if (playlists.length > 0)
        channelTitle = playlists.first.snippet.channelTitle;

      // Put callback on download button
      downloadButton.onClick.listen((_) =>
          downloadPlaylists());
    });
  }).catchError((error) {
    authorizeButton.disabled = true;
    if (error is auth.UserConsentException) {
      authorizeButton.text = 'You did not grant access :(';
      return new Future.error(error);
    } else if (error is youtube.DetailedApiRequestError) {
      authorizeButton.text = 'You do not have a YouTube account.';
      return new Future.error(error);
    } else {
      authorizeButton.text = 'An unknown error occured ($error)';
      return new Future.error(error);
    }
  });
}

/** Displays playlist as thumbnails. */
void displayPlaylists(List<youtube.Playlist> playlists) {
  var playlistGrid = querySelector('#playlist_grid');
  playlistGrid.innerHtml = "";
  for (var playlist in playlists) {
    DivElement thumbnailElement = new DivElement();
    thumbnailElement.setAttribute('class', 'PlaylistThumbnail');

    ImageElement imageElement = new ImageElement(
        src: playlist.snippet.thumbnails.high.url);
    thumbnailElement.children.add(imageElement);

    SpanElement titleElement = new SpanElement();
    titleElement.setAttribute('class', 'PlaylistTitle');
    titleElement.setInnerHtml(playlist.snippet.title);
    thumbnailElement.children.add(titleElement);

    playlistGrid.children.add(thumbnailElement);
  }
}

/** Simple playlist item class that only contains the relevant properties.
 * Used for calculating union with older zip file. */
class SimplePlaylistItem {
  String addedToPlaylistAt;
  String videoId;
  String title;
  String stillPresent;

  SimplePlaylistItem(this.addedToPlaylistAt, this.videoId, this.title,
      [this.stillPresent = '1']);

  SimplePlaylistItem.fromPlaylistItem(youtube.PlaylistItem playlistItem){
    this.addedToPlaylistAt = playlistItem.snippet.publishedAt.toIso8601String();
    this.videoId = playlistItem.snippet.resourceId.videoId;
    this.title =
        playlistItem.snippet.title.replaceAll(',', '\\,'); // escape of comma's
    this.stillPresent = '1';
  }
}

/** Downloads all playlists in a zipped file to the user. */
void downloadPlaylists() {
  startBusy();

  // Creates a stream of futures such that the playlist items of all playlists
  // can be retrieved asynchronously.
  Stream playlistItemStream = new Stream.fromFutures(
      allPlaylists.map((playlist) => receivedPlaylistItems(playlist.id)));

  archive.Archive zipFile = new archive.Archive();

  playlistItemStream.listen((playlistItems) {
    // For each list of playlist items do...

    if (playlistItems.length > 0) {
      // Extract playlist title
      String playlistTitle = allPlaylists
          .firstWhere((playlist) =>
      playlist.id ==
          playlistItems.first.snippet.playlistId)
          .snippet
          .title;
      String fileName = playlistTitle + '.csv';

      // Convert all youtube.PlaylistItem to SimplePlaylistItem
      List<SimplePlaylistItem> currentPlaylistItems = playlistItems.map((
          playlistItem) =>
      new SimplePlaylistItem.fromPlaylistItem(
          playlistItem)).toList();

      // Calculate union if there is an old zip file
      if (oldZipFile != null) {
        String oldCsvFile = getCsvFromArchive(oldZipFile, fileName);
        // Check if file is found
        if (oldCsvFile != null) {
          List<SimplePlaylistItem> oldPlaylistItems = csvToSimplePlaylistItems(
              oldCsvFile);
          // Calculate union
          currentPlaylistItems = calculateUnionPlayListItems(
              oldPlaylistItems, currentPlaylistItems);
        }
      }

      // Encode playlist items to csv in utf-8
      String csv = simplePlaylistItemsToCsv(currentPlaylistItems);
      List<int> csvBytes = new convert.Utf8Encoder().convert(csv);
      int csvLength = csvBytes.length;

      // Create archive file of csv
      archive.ArchiveFile csvFile = new archive.ArchiveFile(
          fileName, csvLength, csvBytes);
      zipFile.addFile(csvFile);
    }
  }, onDone: () {
    // Download zip file to client when all playlists have been converted to csv
    downloadZipFileToClient(zipFile);
  });
}

/** Retrieves all the playlists from the users channel. */
Future<List<youtube.Playlist>> receivedPlaylists() {
  List<youtube.Playlist> playlists = [];
  Future next(String token) {
    return api.playlists.list(
        'snippet,contentDetails,id,localizations,player,status', mine: true,
        pageToken: token)
        .then((results) {
      playlists.addAll(results.items);
      if (results.nextPageToken != null) {
        return next(results.nextPageToken);
      }
      return playlists;
    });
  }
  return next(null);
}

/** Retrieves all playlist items from playlist with playlistId. */
Future<List<youtube.PlaylistItem>> receivedPlaylistItems(String playlistId) {
  List<youtube.PlaylistItem> playlistItems = [];
  Future next(String token, String playlistId) {
    return api.playlistItems.list(
        'snippet',
        pageToken: token,
        playlistId: playlistId,
        maxResults: 50)
        .then((results) {
      playlistItems.addAll(results.items);
      if (results.nextPageToken != null) {
        return next(results.nextPageToken, playlistId);
      }
      return playlistItems;
    });
  }
  return next(null, playlistId);
}

/** Tries to decode the file the user has uploaded as zip file. */
void userUploadedOldZipFile() {
  try {
    File file = querySelector('#input_file').files.first;

    var reader = new FileReader();
    reader.readAsDataUrl(file);
    reader.onLoad.listen((e) {
      String result = reader.result.substring(
          41); // strips away 'data...base64,'
      String base64Archive = Uri.decodeComponent(result);
      List<int> bytesArchive = new convert.Base64Decoder().convert(
          base64Archive);
      oldZipFile = new archive.ZipDecoder().decodeBytes(bytesArchive);
    });
    reader.onError.listen((e) {
      throw new Exception();
    });
  } catch (e) {
    print('Upload failed');
  }
}

/** Downloads the zip file to the client. */
void downloadZipFileToClient(archive.Archive zipFile) {
  try {
    String date = new intl.DateFormat('yyyy-MM-dd').format(new DateTime.now());
    String filename = '[ytpl-backup] ' + channelTitle + ' ' + date;

    // Create archive
    List<int> bytesArchive = new archive.ZipEncoder().encode(zipFile);
    String base64Archive = new convert.Base64Encoder().convert(bytesArchive);
    String uriArchive = Uri.encodeComponent(base64Archive);

    finishBusy();

    // Create and click download element
    AnchorElement tl = document.createElement('a');
    tl
      ..attributes['href'] = 'data:application/zip;base64,' + uriArchive
      ..attributes['download'] = filename + '.zip'
      ..click();
  } catch (e) {
    finishBusy();
    print('Download failed');
  }
}

/** Returns a file from an archive as csv string. */
String getCsvFromArchive(archive.Archive archive, String filename) {
  var archiveFile = archive.findFile(filename);
  if (archiveFile != null) {
    return new convert.Utf8Decoder().convert(archiveFile.content);
  } else {
    // File not found
    return null;
  }
}

/** Calculates the union of old playlist items and the current playlist items. */
List<SimplePlaylistItem> calculateUnionPlayListItems(
    List<SimplePlaylistItem> oldPlaylistItems,
    List<SimplePlaylistItem> currentPlaylistItems) {
  // Lists start with newest video so we need to reverse them
  oldPlaylistItems = oldPlaylistItems.reversed.toList();
  currentPlaylistItems = currentPlaylistItems.reversed.toList();

  List<SimplePlaylistItem> union = new List();
  int i = 0;
  int j = 0;
  while (i < oldPlaylistItems.length || j < currentPlaylistItems.length) {
    if (i < oldPlaylistItems.length && j < currentPlaylistItems.length
        && oldPlaylistItems[i].videoId == currentPlaylistItems[j].videoId) {
      // Old video still present
      union.add(oldPlaylistItems[i]);
      i++;
      j++;
    } else if (i < oldPlaylistItems.length - 1) {
      // Old video was removed
      oldPlaylistItems[i].stillPresent = '0';
      union.add(oldPlaylistItems[i]);
      i++;
    } else {
      // New video was added
      if (currentPlaylistItems[j].title != 'Deleted video')
        union.add(currentPlaylistItems[j]);
      j++;
    }
  }
  return union.reversed.toList();
}

/** Converts csv string to a list of simple playlist items. */
List<SimplePlaylistItem> csvToSimplePlaylistItems(String csv) {
  List<SimplePlaylistItem> simplePlaylistItems = new List();
  // Splits csv file by line and skips header row
  for (String line in csv.split(new RegExp('\r?\n')).sublist(1)) {
    try {
      if (line != '') {
        // '\,' is replaced with '&blabla;' temporarily
        // otherwise video titles containing '\,' will be split as well
        List<String> splitLine = line.replaceAll('\\,', '&blabla;').split(',');
        simplePlaylistItems.add(new SimplePlaylistItem(
            splitLine[0], splitLine[1],
            splitLine[2].replaceAll('&blabla;', '\\,'), splitLine[3]
        ));
      }
    } catch (e) {
      print('Csv could not be parsed');
    }
  }
  return simplePlaylistItems;
}

/** Converts list of simple playlist items to a csv string. */
String simplePlaylistItemsToCsv(List<SimplePlaylistItem> simplePlaylistItems) {
  StringBuffer stringBuffer = new StringBuffer();
  stringBuffer.writeln(
      'addedToPlaylistAt,videoId,title,stillPresent'); // header
  for (SimplePlaylistItem simplePlaylistItem in simplePlaylistItems) {
    stringBuffer.writeln(
        simplePlaylistItem.addedToPlaylistAt + ',' +
            simplePlaylistItem.videoId + ',' +
            simplePlaylistItem.title + ',' +
            simplePlaylistItem.stillPresent
    );
  }
  return stringBuffer.toString();
}

void startBusy() {
  querySelector('#spinner').style.display = 'inline-block';
  querySelector('#input_file').disabled = true;
}

void finishBusy() {
  querySelector('#spinner').style.display = 'none';
  querySelector('#input_file').disabled = false;
}