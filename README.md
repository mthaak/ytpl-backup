YouTube Playlist Backup
=======================

Web application that allows downloading of users YouTube playlists in csv format.

**It is hosted here: [YouTube Playlist Backup] (http://mthaak.com/ytpl-backup/)**

### Motivation
I use YouTube playlists to store my whole collection of favorite tracks which I have collected over the years. However, the videos are sometimes either deleted by the owner, made private or removed by YouTube itself. For this reason I have decided to create this tool which helps me create a backup of the tracks in my playlists. Also it was a good opportunity to use Google's programming language Dart for the first time. 

### Usage
1. **Authorize** the tool to use your YouTube account using the button "Authorize".  

2. (Optional) **Upload** an additional zip file using the button "Upload".  
This zip file must be an older backup downloaded with YouTube Playlist Backup. The tool then calculates the union of the older playlists with the newer playlists such that the removed videos remain in the backup.   

3. **Download** the playlists using the button "**Download".  
The playlists are downloaded in a zip file in whi each csv file corresponds to one playlist.

Try it!
