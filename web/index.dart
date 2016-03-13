import 'dart:async';
import 'dart:html';

import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:archive/archive.dart' as archive;
import 'package:csv/csv.dart' as csv;

final identifier = new auth.ClientId(
    "99747971048-mqnearp1pli825cm3c8ce4hm1i238cgt.apps.googleusercontent.com",
    null);

final scopes = [youtube.YoutubeApi.YoutubeScope];

List<youtube.Playlist> allPlaylists;
youtube.YoutubeApi api;

Future authorizedClient(ButtonElement loginButton, auth.ClientId id, scopes) {
  // Initializes the oauth2 browser flow, completes as soon as authentication
  // calls can be made.
  return auth.createImplicitBrowserFlow(id, scopes)
      .then((auth.BrowserOAuth2Flow flow) {
    // Try getting credentials without user consent.
    // This will succeed if the user already gave consent for this application.
    return flow.clientViaUserConsent(immediate: true).catchError((_) {
      // Ask the user for consent.
      //
      // Asking for consent will create a popup window where the user has to
      // authenticate with Google and authorize this application to access data
      // on it's behalf.
      //
      // Since most browsers block popup windows by default, we can only do this
      // inside an event handler (if a user action triggered a popup it will
      // usually not be blocked).
      // We use the loginButton for this.
      loginButton.text = 'Authorize';
      return loginButton.onClick.first.then((_) {
        return flow.clientViaUserConsent(immediate: false);
      });
    }, test: (error) => error is auth.UserConsentException);
  });
}

main() {
  ButtonElement loginButton = querySelector('#login_button');
  ButtonElement logoutButton = querySelector('#logout_button');

  authorizedClient(loginButton, identifier, scopes).then((client) {
    loginButton.disabled = true;
    loginButton.text = 'You are authorized';
    logoutButton.disabled = false;
    logoutButton.onClick.listen((e) {
      logout();
    });


    api = new youtube.YoutubeApi(client);
    getChannelName(api);

    // check if has youtube account
//      .catchError((error) {
//    if (error is youtube.DetailedApiRequestError){
//      querySelector('#login_button').text = 'You do not have a YouTube account.';
//      //return new Future.error(error);
//    }
//  }

    getAllPlaylists(api).then((playlists) {
      allPlaylists = playlists;
      displayPlaylists(playlists);
      displayDownloadButton();
    });
  }).catchError((error) {
    loginButton.disabled = true;
    if (error is auth.UserConsentException) {
      loginButton.text = 'You did not grant access :(';
      return new Future.error(error);
    } else {
      loginButton.text = 'An unknown error occured ($error)';
      return new Future.error(error);
    }
  });
}

Future<List<youtube.Playlist>> getAllPlaylists(youtube.YoutubeApi api) {
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
  DivElement playlistList = querySelector('#playlist_list');
  for (var playlist in playlists) {
    var row = new TableRowElement();
    var elem = new TableCellElement();
    elem.setInnerHtml(playlist.snippet.title);
    row.children.add(elem);
    playlistList.children.add(row);
  }
}

void displayDownloadButton() {
  ButtonElement downloadButton = new ButtonElement();
  downloadButton.text = 'Download ZIP';
  downloadButton.onClick.listen((e) {
    downloadZipFile();
  });
  querySelector('#playlist_list').children.add(downloadButton);
}

void downloadFileToClient(String filename, String text) {
  AnchorElement tl = document.createElement('a');
  tl
    ..attributes['href'] = 'data:text/plain;charset=utf-8,' +
        Uri.encodeComponent(text)
    ..attributes['download'] = filename
    ..click();
}

void getChannelName(youtube.YoutubeApi api) {
  api.channels.list('contentDetails,snippet', mine: true)
      .then((results) {
    var a = 'a';
  });
}

void logout() {
  ButtonElement loginButton = querySelector('#login_button');
  loginButton.disabled = false;
  loginButton.text = 'Authorize';
}

void downloadZipFile() {
  archive.ZipFile zipFile = createZipFile(allPlaylists);
  //downloadFileToClient('playlists', )
}


Future<List<youtube.Playlist>> getPlaylistItems(String playlistId) {
  List<youtube.PlaylistItem> playlistItems = [];
  Future next(String token, String playlistId) {
    return api.playlistItems.list(
        'snippet',
        pageToken: token,
        playlistId: playlistId,
        maxResults: 50)
        .then((results) {
      playlistItems.addAll(results);
      if (results.nextPageToken != null) {
        return next(results.nextPageToken, playlistId);
      }
      return playlistItems;
    });
  }
  return next(null, playlistId);
}

archive.ZipFile createZipFile(List<youtube.Playlist> playlists) {
  archive.Archive zipFile = new archive.Archive();
  for (youtube.Playlist playlist in playlists) {
    String playlistTitle = playlist.snippet.title;
    createCsvFileOfPlaylist(playlist).then((csvFile) {
      var a = 'a';
//      archive.ArchiveFile archiveFile =
//      zipFile.addFile()
    });
  }
}

Future<String> createCsvFileOfPlaylist(youtube.Playlist playlist) {
  Future next() {
    return getPlaylistItems(playlist.id).then((
        playlistItemListResponse) {
      List list = new List();
      for (var playlistItem in playlistItemListResponse.items) {
        list.add(playlistItemToList(playlistItem));
      }
      return list;
    });
  }
  return next();
}

List playlistItemToList(List<youtube.PlaylistItem> playlistItem) {
  return [
    playlistItem.snippet.publishedAt,
    playlistItem.snippet.resourceId.videoId,
    playlistItem.snippet.title
  ];
}