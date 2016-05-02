Youtube Playlist Backup
=======================

Web application that allows downloading of users Youtube playlists in csv format.

**It is hosted here: [YouTube Playlist Backup] (http://http://mthaak.com/ytpl-backup/)**

### Motivation
I have used YouTube playlists to store my whole collection of favorite tracks over the years catogorized by genre. However videos are sometimes either deleted by the owner, made private or removed by YouTube itself. This is quite a pity since I use my playlists as nostalgic memory of all the music I have listened my life. For this reason I have decided to create this tool which helps me create a backup of my playlists. Also it was nice to use Dart for the first time. 

It works as follows. It retrieves all of the users playlists and puts all the videos in csv files. The csv file for every playlist is put in a zip archive and downloaded to the user.

### Usage
First login on your Youtube account with the button saying "Login on Youtube". After logging in you will see a list of your playlists with their respective thumbnails.

Now you may either choose to download the playlists immediately or upload an additional zip file. This zip file must be an older version downloaded with YouTube Playlist Backup. The tool than calculates the union of the older playlists and the newer playlists such that the removed videos remain in the backup.
