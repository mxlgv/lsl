import os
import std/posix
import std/times
import std/strutils
import std/strformat
import std/algorithm

# FIXME. Emay differ on non-linux systems.
const PathMax = 4096

type
    DirItem = object
        mode: string
        nlink: string
        user: string
        group: string
        size: string
        dateTime: string
        name: string

proc perror(str: string) =
    stderr.writeLine(str & ": " & $strerror(errno))

proc modeToStr(mode: Mode): string =
    var strMode: string; 
    strMode.add(
        if S_ISLNK(mode): 'l'
        elif S_ISCHR(mode): 'c'
        elif S_ISBLK(mode): 'b'
        elif S_ISDIR(mode): 'd'
        elif S_ISFIFO(mode): 'p'
        elif S_ISSOCK(mode): 's'
        else: '-'
    )

    strMode.add(if bool(mode.cint and S_IRUSR): 'r' else: '-')
    strMode.add(if bool(mode.cint and S_IWUSR): 'w' else: '-')

    strMode.add(
        if bool(mode.cint and S_ISUID): 's'
        else:
            if bool(mode.cint and S_IXUSR): 'x'
            else : '-'
    )

    strMode.add(if bool(mode.cint and S_IRGRP): 'r' else: '-');
    strMode.add(if bool(mode.cint and S_IWGRP): 'w' else: '-');
    strMode.add(if bool(mode.cint and S_IXGRP): 'x' else: '-');
    strMode.add(if bool(mode.cint and S_IROTH): 'r' else: '-');
    strMode.add(if bool(mode.cint and S_IWOTH): 'w' else: '-');
    strMode.add(if bool(mode.cint and S_IXOTH): 'x' else: '-');
    
    return strMode

proc getUser(id: Uid): string =
    let pw = getpwuid(id);
    return (if pw.isNil(): $id else: $pw.pw_name)

proc getGroup(id: Gid): string =
    let grp = getgrgid(id)
    return (if grp.isNil(): $id else: $grp.gr_name)

proc timeToStr(unixTime: Timespec): string =
    let dateTime = fromUnix(cast[int64](unixTime)).inZone(local())
    return (
        if  now().year() == dateTime.year():
            dateTime.format("MMM dd hh:mm")
        else:
            dateTime.format("MMM dd  YYYY")
    )

proc getRealPath(name: cstring, mode: Mode): string = 
    let nameStr = $name

    if (not S_ISLNK(mode)):
        return nameStr
    
    var realpath = cast[cstring](alloc(PathMax))
    if realpath.isNil():
        perror("Link reading error")
        quit(QuitFailure)

    var realpathStr: string

    if readlink(name, realpath, PathMax) == -1:
        realpathStr = "?"
    else:
        realpathStr = $realpath
    
    dealloc(realpath)

    return nameStr & " -> " & realpathStr

proc nameCmp(x, y: DirItem): int =
    return cmpIgnoreCase(x.name, y.name)

proc main(): int =
    var path: cstring
    let paramCnt = paramCount()

    if paramCnt < 1:
        path = getcwd(nil, 0)
        if path.isNil():
            perror("Unable to get current directory")
            return QuitFailure

    elif paramCnt == 1:
        path = cstring(paramStr(1))
        if path == "-h":
            stdout.writeLine(
                "Usage: lsl [DIR]\n" &
                "Displays information about files " &
                "(analogue of 'ls -l' written in Nim for fun)."
            )
            return QuitSuccess

        if bool(chdir(path)):
            perror("No access to '" & $path & "' directory")
            return QuitFailure
    
    else:
        stderr.writeLine("Too many arguments. Use -h for help.")
        return QuitFailure

    let dir = opendir(path)
    if dir.isNil():
        perror("Unable to open directory");
        return QuitFailure

    var 
        entry: ptr Dirent
        itemInfo: Stat
        dirItems = newSeq[DirItem]()
        colWidthMax: tuple[nlink: int, user: int, group: int, size: int]
        totalBlocks: Blkcnt

    while true:
        entry = readdir(dir)
        if entry.isNil():
            break

        let name = cast[cstring](entry.d_name.addr)
        if name[0] == '.':
            continue

        if bool(lstat(name, itemInfo)):
            perror("Unable to get information about " & $name)
            continue

        let nlink = $itemInfo.st_nlink
        let size = $itemInfo.st_size

        dirItems.add(
            DirItem(
                mode: modeToStr(itemInfo.st_mode),
                user: getUser(itemInfo.st_uid),
                group: getGroup(itemInfo.st_gid),
                nlink: nlink,
                size: size,
                dateTime: timeToStr(itemInfo.st_mtim),
                name: getRealPath(name, itemInfo.st_mode)
            )
        )

        if nlink.len() > colWidthMax.nlink:
            colWidthMax.nlink = nlink.len()
        
        if size.len() > colWidthMax.size:
            colWidthMax.size = size.len()

        totalBlocks += itemInfo.st_blocks;

    dirItems.sort(nameCmp)
    stdout.writeLine(fmt"total {totalBlocks div 2}")
    
    for dirItem in dirItems:
        let columns = [
            dirItem.mode,
            align(dirItem.nlink,colWidthMax.nlink),
            alignLeft(dirItem.user, colWidthMax.user),
            alignLeft(dirItem.group, colWidthMax.group),
            align(dirItem.size, colWidthMax.size),
            dirItem.dateTime,
            dirItem.name
        ]

        stdout.writeLine(join(columns, " "))
    
    return QuitSuccess

when isMainModule:
   quit(main())
