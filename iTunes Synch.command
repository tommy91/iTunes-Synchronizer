#!/bin/bash

# Playlists are set in the python code below!

# Device Path: [ to edit for changes ]
CONNECTED_DEVICES_PATH="/Volumes/"
USB_DEVICE_NAME="My USB Drive"


printf "\n#################### iTunes-USB Synchronizer ####################\n\n" 

usb_device_path="$CONNECTED_DEVICES_PATH$USB_DEVICE_NAME/"

# Check if the device is connected
if [ $(ls $CONNECTED_DEVICES_PATH | grep -c "$USB_DEVICE_NAME") -eq 1 ]; then
	printf "Selected Device Path: '$usb_device_path'\n\n"
else
	printf "Device '$USB_DEVICE_NAME' not found!\n\n"
	echo "Connected devides:"
	echo "$(ls $CONNECTED_DEVICES_PATH | sed 's/^/ - /')"
	printf "\nSet USB_DEVICE_NAME to the correct device name!\nBye\n\n"
	exit 0
fi


# ----- BEGIN PYTHON CALL -----

python - "$usb_device_path" << 'EOF'
# -*- coding: utf-8 -*-
import os
import sys
import subprocess
import unicodedata
from pprint import pprint


# Playlists to synch: [ to edit for changes ]
# from iTunes to USB (or another device) only
PLAYLISTS = [
	{'iTunes': "Itunes Playlist 1", 'USB': "USB Folder 1"},
	{'iTunes': "Itunes Playlist 2", 'USB': "USB Folder 2"}
]

# Uncomment the appropriate line
app_name = "Music"  # for Catalina
# app_name = "iTunes"  # previous versions


def normalize(s):
	# To match strings with accents in different encodings
	return unicodedata.normalize('NFC', s.decode('utf8'))


def getFileMetadata(filepath,tag):
	p1 = subprocess.Popen(['ffprobe',filepath,'-show_format'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	p2 = subprocess.Popen(['grep','TAG:' + tag], stdin=p1.stdout, stdout=subprocess.PIPE)
	p3 = subprocess.Popen(['cut','-d','=','-f','2'], stdin=p2.stdout, stdout=subprocess.PIPE)
	output, error = p3.communicate()
	return output.strip()


def getItunesPlaylistsNames():
	applescript_command = "tell application \"" + app_name + "\" to get name of playlists"
	itunes_process = subprocess.Popen(['osascript','-e',applescript_command], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	itunes_playlists, ip_err = itunes_process.communicate()
	if ip_err:
		raise Exception("Error: " + str(ip_err))
	itunes_playlists_names = []
	print "iTunes playlists names:"
	for playlist_name in (itunes_playlists).split(','):
		print "- " + str(playlist_name)
		itunes_playlists_names.append(playlist_name.strip())
	return itunes_playlists_names


def getItunesPlaylistFilepaths(itunes_playlist_name):
	applescript_command = "tell application \"" + app_name + "\" to get {location} of (every track in playlist \"" + itunes_playlist_name + "\")"
	itunes_process = subprocess.Popen(['osascript','-e',applescript_command], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	itunes_data, ip_err = itunes_process.communicate()
	if ip_err:
		raise Exception("Error: " + str(ip_err))
	itunes_songs_list = []
	for path in (itunes_data).split('alias')[1:]:
		path = path.strip()
		if path[-1] == ',':
			path = path[:-1]
		itunes_songs_list.append('/' + '/'.join(path.split(':')[1:]))
	return itunes_songs_list


def getUsbSongsList(usb_playlist_path):
	usb_songs_list = []
	for f in os.listdir(usb_playlist_path):
		if os.path.isfile(os.path.join(usb_playlist_path,f)):
			usb_songs_list.append(os.path.join(usb_playlist_path,f))
	return usb_songs_list


def getUsbSongs(usb_playlist_path, usb_songs_list):
	songs = {}
	usb_filenames = []

	print "\nUSB songs: ( in '" + usb_playlist_path + "' )"
	if len(usb_songs_list) == 0:
		print "    No songs found." 
	else:
		for usb_song in usb_songs_list:
			
			usb_filename = usb_song.split('/')[-1]
			print usb_filename
			usb_filenames.append(usb_filename)
			
			# Get artist and title of the song from file metadata
			# if the title is missing get it from the filename
			artist = getFileMetadata(usb_song,'artist')
			title = getFileMetadata(usb_song,'title')
			if title == '':
				title = usb_song.split('/')[-1][:-4]
			# print "    " + artist + " - " + title
			
			# The title is normalized to prevent the unmatching of
			# the same accented character in different encodings
			if artist in songs:
				songs[artist][normalize(title)] = usb_song
			else:
				songs[artist] = {normalize(title): usb_song}

	# pprint(songs)

	return songs, usb_filenames


def getSongsToAddAndToRemove(itunes_songs_list,itunes_playlist_name, songs, usb_filenames):
	songs_to_add = []
	songs_to_remove = []

	if len(itunes_songs_list) == 0:
		print "\niTunes playlist '" + itunes_playlist_name + "' is empty!"
	else:
		print "\niTunes songs in playlist '" + itunes_playlist_name + "'"
		print "( prefix: " + '/'.join(itunes_songs_list[0].split('/')[:-3]) + " )"
		for itunes_song in itunes_songs_list:
			print ('/').join(itunes_song.split('/')[-3:])
			
			# Get artist and title of the song from file metadata
			# if the title is missing get it from the filename
			artist = getFileMetadata(itunes_song,'artist')
			title = getFileMetadata(itunes_song,'title')
			if title == '':
				title = itunes_song.split('/')[-1][:-4]
			# print "   " + artist + " - " + title

			if (artist not in songs) or (normalize(title) not in songs[artist]):
				# iTunes song is not in USB => it must be added.
				# The new filename is the same as the filename in iTunes
				# except for the eventual track number at the beginning used by iTunes

				itunes_filename = itunes_song.split('/')[-1]
				if title[0] == itunes_filename[0]:
					# If no track number at the beginning use the filename
					new_filename = itunes_filename
				else:
					# Skip the track number at the beginning
					# or use the same filename
					# if cannot find the first char of the title
					first_char_index = itunes_filename.find(title[0])
					if first_char_index	== -1:
						new_filename = itunes_filename
					else:
						new_filename = itunes_filename[first_char_index:]
				if new_filename in usb_filenames:
					# If the filename is already in use in the directory
					# append at the end the artist			
					itunes_artist = itunes_song.split('/')[-3]
					extension = new_filename[-4:]
					new_filename = new_filename[:-4] + " (" + itunes_artist + ")" + extension
				song = {'new_filename': new_filename, 'path': itunes_song}
				songs_to_add.append(song)

			else:
				# iTunes song is in USB => no need to update
				# can remove it from songs
				del songs[artist][normalize(title)]
					
				if not songs[artist]:
					# If no more songs of that artist
					# can remove the artist from songs
					del songs[artist]

	# The remaining songs are not in the iTunes playlist anymore
	# so can be removed from usb
	for artist in songs:
		for title in songs[artist]:
			songs_to_remove.append(songs[artist][title])

	# printSongsToAdd(songs_to_add)
	# printSongsToRemove(songs_to_remove)

	return songs_to_add, songs_to_remove


def printSongsToAdd(songs_to_add):
	print "\nSongs to add:"
	if len(songs_to_add) > 0:
		for song in songs_to_add:
			print song['path']
	else:
		print "No new songs to add!"


def printSongsToRemove(songs_to_remove):
	print "\nSongs to remove:"
	if len(songs_to_remove) > 0:
		for song in songs_to_remove:
			print song
	else:
		print "No songs to remove!"


def addNewSongs(songs_to_add, usb_playlist_path):
	num_songs_to_add = len(songs_to_add)
	if num_songs_to_add > 0:
		print "\nAdd new songs:"
		path_from = ('/').join(songs_to_add[0]['path'].split('/')[:-3])
		print "( from: " + path_from + ", to: " + usb_playlist_path + " )"
		counter = 0
		for song in songs_to_add:
			counter += 1
			new_path = usb_playlist_path + "/" + song['new_filename']
			path = ('/').join(song['path'].split('/')[-3:])
			print "[ " + str(counter) + " di " + str(num_songs_to_add) + " ]   " + path + "   ->   " + song['new_filename'],
			copy_process = subprocess.Popen(['cp','-v',song['path'],new_path], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
			output, error = copy_process.communicate()
			if error:
				print "   [ " + str(error) + " ]"
			elif output.find(':') > -1:
				print "   [ " + str(output) + " ]"
			else:
				print "   [ ok ]"
			print "   " + str(output)
	else:
		print "\nNo new songs to add!"


def removeSongs(songs_to_remove, usb_playlist_path):
	num_songs_to_remove = len(songs_to_remove)
	if num_songs_to_remove > 0:
		print "\nRemove songs: ( from: " + usb_playlist_path + " )"
		counter = 0
		for song in songs_to_remove:
			counter += 1
			print "[ " + str(counter) + " di " + str(num_songs_to_remove) + " ]   " + song.split('/')[-1],
			remove_process = subprocess.Popen(['rm',song], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
			output, error = remove_process.communicate()
			if error:
				print "   [ " + str(error) + " ]"
			else:
				print "   [ removed ]"
	else:
		print "\nNo songs to remove!"


if __name__ == "__main__":

	usb_device_path = sys.argv[1]

	try:
		itunes_playlists_names = getItunesPlaylistsNames()

		for playlist in PLAYLISTS:

			print "\nSynch USB playlist '" + playlist['USB'] + "' with iTunes playlist '" + playlist['iTunes'] + "':\n"

			# Check iTunes playlist
			if playlist['iTunes'] in itunes_playlists_names:
				itunes_playlist_name = playlist['iTunes']
			else:
				print "iTunes playlist '" + playlist['iTunes'] + "' not found."
				print "Skip to the next playlist."
				continue

			# Check usb path
			usb_playlist_path = usb_device_path + playlist['USB']	# No slash at the end
			if not os.path.exists(usb_playlist_path):
				print "Directory '" + usb_playlist_path + "' not found."
				print "Create directory '" + usb_playlist_path + "'... ",
				os.makedirs(usb_playlist_path)
				print "ok"
		
			usb_songs_list = getUsbSongsList(usb_playlist_path)
			songs, usb_filenames = getUsbSongs(usb_playlist_path, usb_songs_list)
			itunes_songs_list = getItunesPlaylistFilepaths(itunes_playlist_name)
			songs_to_add, songs_to_remove = getSongsToAddAndToRemove(itunes_songs_list,itunes_playlist_name, songs, usb_filenames)
			addNewSongs(songs_to_add, usb_playlist_path)
			removeSongs(songs_to_remove, usb_playlist_path)

			print "\n"
	
	except Exception, msg: 
		print msg
		sys.exit(1)

	sys.exit(0)

EOF

# ----- END PYTHON CALL ----- 


echo ""
echo "done"
