# iTunes-Synchronizer

The script allows the synchronization between iTunes playlists and folders of a connected (eventually external) drive.  
The synchronization works only from an iTunes playlist to a specified folder, not viceversa.  
All the songs in the iTunes playlist which are not in the folder are copied in the folder.  
Then, all the songs in the folder which are not in the iTunes playlist will be removed from the folder.  

Case scenario: synchronize some iTunes playlists with an USB to use it in your car.  

For your personal use, edit in the file the following bash variables with your specifics:  
CONNECTED_DEVICES_PATH="/Volumes/"  
USB_DEVICE_NAME="My USB Drive"  
And setup the matching Playlist-Folder at the beginning of the python code:  
PLAYLISTS = [  
  {'iTunes': "iTunes Playlist 1", 'USB': "USB Folder 1"},  
  {'iTunes': "iTunes Playlist 2", 'USB': "USB Folder 2"}  
]  
You can add how many matches you want.  

After allowing +x permission to the file you can just double click it to run the script.  

Tested on macOS Mojave.  
Hope it will work also on Unix environment.   
For Windows there are probably some changes to do.  
