magick ^
	( %1[32x32+32+64] ( +clone +clone ) +append ( +clone ) -append -repage +00+32 ) ^
	( %1[32x32+00+32] ( +clone +clone ) -append ( +clone ) +append -repage +00+00 ) ^
	( %1[32x32+32+00] ( +clone +clone ) +append ( +clone ) -append -repage +00+00 ) ^
	( %1[32x32+64+32] ( +clone +clone ) -append ( +clone ) +append -repage +32+00 ) ^
	-background #00000000 -flatten ^
	%1 +swap +append ^
	blobhash.png
if NOT "%errorlevel%"=="0" pause
