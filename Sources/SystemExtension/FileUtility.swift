import SystemPackage
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import SyscallValue
import KwiftC

public struct FileUtility {

  @_alwaysEmitIntoClient
  public static func createDirectory(_ path: FilePath, permissions: FilePermissions = .directoryDefault) throws {
#if DEBUG && Xcode
    print(#function, path)
#endif
    assert(!path.isEmpty)
    try valueOrErrno(
      path.withPlatformString { str in
        mkdir(str, permissions.rawValue)
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func createDirectoryIntermediately(_ path: FilePath, permissions: FilePermissions = .directoryDefault) throws {
    do {
      let fileStat = try fileStatus(path)
      if fileStat.fileType == .directory {
        return
      } else {
        throw Errno.fileExists
      }
    } catch Errno.noSuchFileOrDirectory {
      // create parent
      var parent = path
      if parent.removeLastComponent(), !parent.isEmpty {
        try createDirectoryIntermediately(parent, permissions: permissions)
      }
    }
    try createDirectory(path, permissions: permissions)
  }

  @_alwaysEmitIntoClient
  public static func remove(_ path: FilePath) throws {
#if DEBUG && Xcode
    print(#function, self)
#endif
    assert(!path.isEmpty)
    let s = try fileStatus(path, flags: .noFollow)
    if s.fileType == .directory {
      try removeDirectoryRecursive(path)
    } else {
      try unlinkFile(path)
    }
  }

  @_alwaysEmitIntoClient
  public static func unlinkFile(_ path: FilePath) throws {
#if DEBUG && Xcode
    print(#function, self)
#endif
    assert(!path.isEmpty)
    try valueOrErrno(
      path.withPlatformString { str in
        unlink(str)
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func removeDirectory(_ path: FilePath) throws {
#if DEBUG && Xcode
    print(#function, self)
#endif
    assert(!path.isEmpty)
    try valueOrErrno(
      path.withPlatformString { str in
        rmdir(str)
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func removeDirectoryRecursive(_ path: FilePath) throws {
#if DEBUG && Xcode
    print(#function, self)
#endif
    try Directory.open(path)
      .closeAfter { directory in
        var entry = Directory.Entry()
        while try directory.read(into: &entry) {
          if entry.isInvalid {
            continue
          }
          let entryName = entry.name
          let childPath = path.appending(entryName)
          switch entry.fileType {
          case .directory: try removeDirectoryRecursive(childPath)
          default: try unlinkFile(childPath)
          }
        }
      } // Directory open
    try removeDirectory(path)
  }

  @_alwaysEmitIntoClient
  public static func fileStatus(_ fd: FileDescriptor) throws -> FileStatus {
    var s = FileStatus(.init())
    try fileStatus(fd, into: &s)
    return s
  }

  @_alwaysEmitIntoClient
  public static func fileStatus(_ fd: FileDescriptor, into status: inout FileStatus) throws {
    try valueOrErrno(
      fstat(fd.rawValue, &status.status)
    )
  }

  @_alwaysEmitIntoClient
  public static func fileStatus(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory, flags: AtFlags = []) throws -> FileStatus {
    var s = FileStatus(.init())
    try fileStatus(path, relativeTo: fd, flags: flags, into: &s)
    return s
  }

  @_alwaysEmitIntoClient
  public static func fileStatus(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory, flags: AtFlags = [], into status: inout FileStatus) throws {
    assert(!path.isEmpty)
    assert(flags.isSubset(of: [.noFollow]))
    try valueOrErrno(
      path.withPlatformString { path in
        fstatat(fd.rawValue, path, &status.status, flags.rawValue)
      })
  }
}

// MARK: symbolic link
extension FileUtility {

  @_alwaysEmitIntoClient
  public static func symLink(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory, toDestination dest: FilePath) throws {
    assert(!path.isEmpty)
//    assert(!dest.isEmpty)
    try valueOrErrno(
      path.withPlatformString { path in
        dest.withPlatformString { dest in
          symlinkat(dest, fd.rawValue, path)
        }
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func readLink(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory) throws -> String {
    assert(!path.isEmpty)
    let count = Int(PATH_MAX) + 1
    return try .init(capacity: count) { ptr in
      try path.withPlatformString { path in
        let newCount = readlinkat(fd.rawValue, path, ptr.assumingMemoryBound(to: CChar.self), count)
        if newCount == -1 {
          throw Errno.current
        }
        return newCount
      }
    }
  }

  @_alwaysEmitIntoClient
  public static func realPath(_ path: FilePath) throws -> FilePath {
    assert(!path.isEmpty)
    return try .init(String(capacity: Int(PATH_MAX) + 1, { buffer in
      try path.withPlatformString { path in
        let cstr = buffer.assumingMemoryBound(to: CChar.self)
        let ptr = realpath(path, cstr)
        if ptr == nil {
          throw Errno.current
        }
        assert(ptr == cstr)
        return strlen(cstr)
      }
    }))
  }
}

// MARK: chmod
extension FileUtility {

  @_alwaysEmitIntoClient
  public static func changeMode(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory, permissions: FilePermissions, flags: AtFlags = []) throws {
    assert(!path.isEmpty)
    assert(flags.isSubset(of: [.noFollow]))
    try valueOrErrno(
      path.withPlatformString { path in
        fchmodat(fd.rawValue, path, permissions.rawValue, flags.rawValue)
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func changeMode(_ fd: FileDescriptor, permissions: FilePermissions) throws {
    try valueOrErrno(
      fchmod(fd.rawValue, permissions.rawValue)
    )
  }

}

// MARK: chflags
extension FileUtility {

  public typealias FileFlags = UInt32

  @_alwaysEmitIntoClient
  public static func changeFlags(_ path: FilePath, flags: FileFlags) throws {
    try valueOrErrno(
      path.withPlatformString { path in
        chflags(path, flags)
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func changeFlags(_ fd: FileDescriptor, flags: FileFlags) throws {
    try valueOrErrno(
      fchflags(fd.rawValue, flags)
    )
  }
}

// MARK: truncate
extension FileUtility {

  @_alwaysEmitIntoClient
  public static func changeFileSize(_ path: FilePath, size: Int) throws {
    assert(!path.isEmpty)
    try valueOrErrno(
      path.withPlatformString { path in
        truncate(path, off_t(size))
      }
    )
  }

  @_alwaysEmitIntoClient
  public static func changeFileSize(_ fd: FileDescriptor, size: Int) throws {
    try valueOrErrno(
      ftruncate(fd.rawValue, off_t(size))
    )
  }

}

// MARK: access
extension FileUtility {

  public struct Accessibility: OptionSet {

    @_alwaysEmitIntoClient
    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    @_alwaysEmitIntoClient
    internal init(_ rawValue: Int32) {
      self.rawValue = .init(rawValue)
    }

    @_alwaysEmitIntoClient
    public let rawValue: Int32

    /// test for existence of file
    @_alwaysEmitIntoClient
    public static var existence: Self { .init(F_OK) }

    /// test for execute or search permission
    @_alwaysEmitIntoClient
    public static var execute: Self { .init(X_OK) }

    /// test for write permission
    @_alwaysEmitIntoClient
    public static var write: Self { .init(W_OK) }

  }

  @_alwaysEmitIntoClient
  public static func checkAccessibility(_ path: FilePath, relativeTo fd: FileDescriptor = .currentWorkingDirectory, accessibility: Accessibility, flags: AtFlags = []) -> Bool {
    assert(!path.isEmpty)
    assert(flags.isSubset(of: [.noFollow, .effectiveAccess]))
    return path.withPlatformString { path in
      faccessat(fd.rawValue, path, accessibility.rawValue, flags.rawValue) == 0
    }
  }

}

public struct AtFlags: OptionSet {

  @_alwaysEmitIntoClient
  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  @_alwaysEmitIntoClient
  internal init(_ rawValue: Int32) {
    self.rawValue = .init(rawValue)
  }

  @_alwaysEmitIntoClient
  public let rawValue: Int32

  /// Use effective ids in access check
  @_alwaysEmitIntoClient
  public static var effectiveAccess: Self { .init(AT_EACCESS) }

  /// Act on the symlink itself not the target
  @_alwaysEmitIntoClient
  public static var noFollow: Self { .init(AT_SYMLINK_NOFOLLOW) }

  /// Act on target of symlink
  @_alwaysEmitIntoClient
  public static var follow: Self { .init(AT_SYMLINK_FOLLOW) }

  /// Path refers to directory
  @_alwaysEmitIntoClient
  public static var removeDir: Self { .init(AT_REMOVEDIR) }

  /// Return real device inodes resides on for fstatat(2)
  @_alwaysEmitIntoClient
  public static var realDevice: Self { .init(AT_REALDEV) }

  /// Use only the fd and Ignore the path for fstatat(2)
  @_alwaysEmitIntoClient
  public static var fdOnly: Self { .init(AT_FDONLY) }
}
