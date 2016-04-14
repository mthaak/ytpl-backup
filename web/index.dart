import 'dart:async';
import 'dart:html';

import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:archive/archive.dart' as archive;
import 'package:intl/intl.dart' as intl;
import 'dart:convert' as convert;

final identifier = new auth.ClientId(
    "99747971048-mqnearp1pli825cm3c8ce4hm1i238cgt.apps.googleusercontent.com",
    null);

final scopes = [youtube.YoutubeApi.YoutubeScope];

youtube.YoutubeApi api;
List<youtube.Playlist> allPlaylists;
archive.Archive zipFile;
String channelTitle;

Future authorizedClient(ButtonElement loginButton, auth.ClientId id, scopes) {
  return auth.createImplicitBrowserFlow(id, scopes)
      .then((auth.BrowserOAuth2Flow flow) {
    return flow.clientViaUserConsent(immediate: true).catchError((_) {
      loginButton.text = 'Login on YouTube';
      return loginButton.onClick.first.then((_) {
        return flow.clientViaUserConsent(immediate: false);
      });
    }, test: (error) => error is auth.UserConsentException);
  });
}

main() {
  ButtonElement loginButton = querySelector('#login_button');

  authorizedClient(loginButton, identifier, scopes).then((client) {
    loginButton.disabled = true;
    loginButton.text = 'You are authorized';

    api = new youtube.YoutubeApi(client);

    receivedPlaylists().then((playlists) {
      allPlaylists = playlists;
      displayPlaylists(playlists);

      if (playlists.length > 0)
        channelTitle = playlists.first.snippet.channelTitle;

      // Enable download button
      querySelector("#download_button").onClick.listen((_) =>
          downloadPlaylists());
    });
  }).catchError((error) {
    loginButton.disabled = true;
    if (error is auth.UserConsentException) {
      loginButton.text = 'You did not grant access :(';
      return new Future.error(error);
    } else if (error is youtube.DetailedApiRequestError) {
      loginButton.text = 'You do not have a YouTube account.';
      return new Future.error(error);
    } else {
      loginButton.text = 'An unknown error occured ($error)';
      return new Future.error(error);
    }
  });
}

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

void displayPlaylists(List<youtube.Playlist> playlists) {
  var playlistList = querySelector('#playlist_grid');
  for (var playlist in playlists) {
    DivElement thumbnailElement = new DivElement();
    thumbnailElement.setAttribute('class', 'Thumbnail');

    ImageElement imageElement = new ImageElement(
        src: playlist.snippet.thumbnails.high.url);
    thumbnailElement.children.add(imageElement);

    SpanElement titleElement = new SpanElement();
    titleElement.setAttribute('class', 'Title');
    titleElement.setInnerHtml(playlist.snippet.title);
    thumbnailElement.children.add(titleElement);

    playlistList.children.add(thumbnailElement);
  }
}

void downloadPlaylists() {
  Stream playlistItemStream = new Stream.fromFutures(
      allPlaylists.map((playlist) => receivedPlaylistItems(playlist.id)));

  zipFile = new archive.Archive();

  playlistItemStream.listen((playlistItems) {
    if (playlistItems.length > 0) {
      String playlistTitle = allPlaylists
          .firstWhere((playlist) => playlist.id ==
          playlistItems.first.snippet.playlistId)
          .snippet
          .title;
      String fileName = playlistTitle + '.csv';

      String csv = playlistItemsToCsv(playlistItems);
      List<int> csvBytes = new convert.Utf8Encoder().convert(csv);
      int csvLength = csvBytes.length;

      archive.ArchiveFile csvFile = new archive.ArchiveFile(
          fileName, csvLength, csvBytes);
      zipFile.addFile(csvFile);
    }
  }, onDone: () {
    downloadFileToClient();
  });
}

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

String playlistItemsToCsv(List<youtube.PlaylistItem> playlistItems) {
  StringBuffer stringBuffer = new StringBuffer();
  stringBuffer.writeln('publishedAt,videoId,title'); // header
  for (youtube.PlaylistItem playlistItem in playlistItems) {
    stringBuffer.writeln(
        playlistItem.snippet.publishedAt.toIso8601String() + ',' +
            playlistItem.snippet.resourceId.videoId + ',' +
            playlistItem.snippet.title);
  }
  return stringBuffer.toString();
}

void downloadFileToClient() {
  String date = new intl.DateFormat("yyyy-MM-dd").format(new DateTime.now());
  String filename = '[ytpl-backup] ' + channelTitle + ' ' + date;

  List<int> bytesArchive = new archive.ZipEncoder().encode(zipFile);
  String base64Archive = new convert.Base64Encoder().convert(bytesArchive);
  String uriArchive = Uri.encodeComponent(base64Archive);

  AnchorElement tl = document.createElement('a');
  tl
    ..attributes['href'] = 'data:application/zip;base64,' + uriArchive
    ..attributes['download'] = filename + '.zip'
    ..click();
}