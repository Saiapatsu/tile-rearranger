:: This constructs the image similarly to montage,
:: except it doesn't suck like montage

magick -background #00000000 -size 32x32 ^
	( ^
		xc:#00000000 ^
		%1[32x32+64+32] ^
		%1[32x32+32+64] ^
		%1[32x32+160+64] ^
		%1[32x32+0+32] ^
		( %1[32x32+0+32] %1[32x32+64+32] +repage -flatten ) ^
		%1[32x32+96+64] ^
		%1[32x32+128+64] ^
		%1[32x32+32+0] ^
		%1[32x32+160+0] ^
		( %1[32x32+32+0] %1[32x32+32+64] +repage -flatten ) ^
		%1[32x32+160+32] ^
		%1[32x32+96+0] ^
		%1[32x32+128+0] ^
		%1[32x32+96+32] ^
		%1[32x32+128+32] ^
	+append ) ^
	( ^
		( -size 32x32  xc:#00000000 %1[32x32+64+64] +append ( +clone +clone +clone +clone +clone +clone +clone ) +append ) ^
		( -size 64x32  xc:#00000000 %1[32x32+00+64] ( +clone ) +append ( +clone +clone +clone ) +append ) ^
		( -size 128x32 xc:#00000000 %1[32x32+00+00] ( +clone +clone +clone ) +append ( +clone ) +append ) ^
		( -size 256x32 xc:#00000000 %1[32x32+64+00] ( +clone +clone +clone +clone +clone +clone +clone ) +append ) ^
	+repage -flatten ) ^
	-append ^
	%~2
if NOT "%errorlevel%"=="0" pause
