Youtube Playlist Backup
=======================

Web application that allows downloading of users Youtube playlists in csv format.

**It is hosted here: [YouTube Playlist Backup] (http://mthaak.com/ytpl-backup/)**

### Motivation
I use YouTube playlists to store my whole collection of my favorite tracks over the years. However videos are sometimes either deleted by the owner, made private or removed by YouTube itself. For this reason I have decided to create this tool which helps me create a backup of my playlists. Also it was nice to use Dart for the first time. 

### Usage
First authorize using your YouTube account by pressing the button saying "Authorize". After authorization you will see a list of your playlists with their respective thumbnails.

Now you may either choose to download the playlists immediately or upload an additional zip file. This zip file must be an older backup downloaded with YouTube Playlist Backup. The tool then calculates the union of the older playlists with the newer playlists such that the removed videos remain in the backup.
