NIM = nim
UPX = upx
STRIP = strip
NIM_FLAGS = c --styleCheck:error

release:
	$(NIM) $(NIM_FLAGS) --stackTrace:off -d:release --opt=size lsl.nim
	$(STRIP) -s lsl

release-upx: release
	$(UPX) lsl

debug:
	$(NIM) $(NIM_FLAGS) lsl.nim

clean:
	rm lsl
