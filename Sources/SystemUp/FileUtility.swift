import SystemPackage
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
import CSystemUp
#endif
import Foundation
import SyscallValue
import CUtility

public enum FileUtility {
}

public extension FileUtility {

  static func createDirectory(_ option: FilePathOption, permissions: FilePermissions = .directoryDefault) throws {
    assert(!option.path.isEmpty)
    try nothingOrErrno(retryOnInterrupt: false) {
      option.path.withPlatformString { path in
        mkdirat(option.relativedDirFD.rawValue, path, permissions.rawValue)
      }
    }.get()
  }

  static func unlink(_ option: FilePathOption, flags: AtFlags = []) throws {
    assert(!option.path.isEmpty)
    assert(flags.isSubset(of: [.removeDir]))
    try nothingOrErrno(retryOnInterrupt: false) {
      option.path.withPlatformString { path in
        unlinkat(option.relativedDirFD.rawValue, path, flags.rawValue)
      }
    }.get()
  }

  static func fileStatus(_ fd: FileDescriptor) throws -> FileStatus {
    var s = FileStatus()
    try fileStatus(fd, into: &s)
    return s
  }

  static func fileStatus(_ fd: FileDescriptor, into status: inout FileStatus) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      fstat(fd.rawValue, &status.status)
    }.get()
  }

  static func fileStatus(_ option: FilePathOption, flags: AtFlags = []) throws -> FileStatus {
    var s = FileStatus()
    try fileStatus(option, flags: flags, into: &s)
    return s
  }

  static func fileStatus(_ option: FilePathOption, flags: AtFlags = [], into status: inout FileStatus) throws {
    assert(!option.path.isEmpty)
    assert(flags.isSubset(of: [.noFollow]))
    try nothingOrErrno(retryOnInterrupt: false) {
      option.path.withPlatformString { path in
        fstatat(option.relativedDirFD.rawValue, path, &status.status, flags.rawValue)
      }
    }.get()
  }
}

// MARK: symbolic link
public extension FileUtility {

  static func createSymbolicLink(_ option: FilePathOption, toDestination dest: FilePath) throws {
    assert(!option.path.isEmpty)
    //    assert(!dest.isEmpty)
    try nothingOrErrno(retryOnInterrupt: false) {
      option.path.withPlatformString { path in
        dest.withPlatformString { dest in
          symlinkat(dest, option.relativedDirFD.rawValue, path)
        }
      }
    }.get()
  }

  static func readLink(_ option: FilePathOption) throws -> String {
    assert(!option.path.isEmpty)
    let count = Int(PATH_MAX) + 1
    return try .init(capacity: count) { ptr in
      try option.path.withPlatformString { path in
        let newCount = readlinkat(option.relativedDirFD.rawValue, path, ptr.assumingMemoryBound(to: CChar.self), count)
        if newCount == -1 {
          throw Errno.current
        }
        return newCount
      }
    }
  }

  static func realPath(_ path: FilePath) throws -> FilePath {
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
public extension FileUtility {

  static func set(_ option: FilePathOption, permissions: FilePermissions, flags: AtFlags = []) throws {
    assert(!option.path.isEmpty)
    assert(flags.isSubset(of: [.noFollow]))
    try nothingOrErrno(retryOnInterrupt: false) {
      option.path.withPlatformString { path in
        fchmodat(option.relativedDirFD.rawValue, path, permissions.rawValue, flags.rawValue)
      }
    }.get()
  }

  static func set(_ fd: FileDescriptor, permissions: FilePermissions) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      fchmod(fd.rawValue, permissions.rawValue)
    }.get()
  }

}

// MARK: chflags
#if canImport(Darwin)
public extension FileUtility {

  struct FileFlags: OptionSet {

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    internal init(_ rawValue: Int32) {
      self.rawValue = .init(rawValue)
    }

    public let rawValue: UInt32

    /// Do not dump the file.
    public static var userNoDump: Self { .init(UF_NODUMP) }

    /// The file may not be changed.
    public static var userImmutable: Self { .init(UF_IMMUTABLE) }

    /// The file may only be appended to.
    public static var userAppend: Self { .init(UF_APPEND) }

    /// The directory is opaque when viewed through a union stack.
    public static var userOpaque: Self { .init(UF_OPAQUE) }

    /// The file or directory is not intended to be displayed to the user.
    public static var userHidden: Self { .init(UF_HIDDEN) }

    /// The file has been archived.
    public static var superArchived: Self { .init(SF_ARCHIVED) }

    /// The file may not be changed.
    public static var superImmutable: Self { .init(SF_IMMUTABLE) }

    /// The file may only be appended to.
    public static var superAppend: Self { .init(SF_APPEND) }

    /// The file is a dataless placeholder.  The system will attempt to materialize it when accessed according to the dataless file materialization policy of the accessing thread or process.  See getiopolicy_np(3).
    public static var superDataless: Self { .init(SF_DATALESS) }

  }

  static func set(_ path: FilePath, flags: FileFlags) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      path.withPlatformString { path in
        chflags(path, flags.rawValue)
      }
    }.get()
  }

  static func set(_ fd: FileDescriptor, flags: FileFlags) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      fchflags(fd.rawValue, flags.rawValue)
    }.get()
  }
}
#endif // chflags end

// MARK: truncate
public extension FileUtility {

  static func truncate(_ path: FilePath, size: Int) throws {
    assert(!path.isEmpty)
    try nothingOrErrno(retryOnInterrupt: false) {
      path.withPlatformString { path in
        system_truncate(path, off_t(size))
      }
    }.get()
  }

  static func truncate(_ fd: FileDescriptor, size: Int) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      system_ftruncate(fd.rawValue, off_t(size))
    }.get()
  }

}

// MARK: access
public extension FileUtility {

  struct Accessibility: OptionSet {

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    internal init(_ rawValue: Int32) {
      self.rawValue = .init(rawValue)
    }

    public let rawValue: Int32

    /// test for existence of file
    public static var existence: Self { .init(F_OK) }

    /// test for execute or search permission
    public static var execute: Self { .init(X_OK) }

    /// test for write permission
    public static var write: Self { .init(W_OK) }

  }

  static func check(_ option: FilePathOption, accessibility: Accessibility, flags: AtFlags = []) -> Bool {
    assert(!option.path.isEmpty)
    assert(flags.isSubset(of: [.noFollow, .effectiveAccess]))
    return option.path.withPlatformString { path in
      system_access(option.relativedDirFD.rawValue, path, accessibility.rawValue, flags.rawValue) == 0
    }
  }

}

public extension FileUtility {
  struct AtFlags: OptionSet {

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    internal init(_ rawValue: Int32) {
      self.rawValue = .init(rawValue)
    }

    public let rawValue: Int32

    /// Use effective ids in access check
    public static var effectiveAccess: Self { .init(AT_EACCESS) }

    /// Act on the symlink itself not the target
    public static var noFollow: Self { .init(AT_SYMLINK_NOFOLLOW) }

    /// Act on target of symlink
    public static var follow: Self { .init(AT_SYMLINK_FOLLOW) }

    /// Path refers to directory
    public static var removeDir: Self { .init(AT_REMOVEDIR) }

    /// Return real device inodes resides on for fstatat(2)
    #if canImport(Darwin)
    public static var realDevice: Self { .init(AT_REALDEV) }
    #endif

    /// Use only the fd and Ignore the path for fstatat(2)
    #if canImport(Darwin)
    public static var fdOnly: Self { .init(AT_FDONLY) }
    #endif
  }

}

// MARK: rename
public extension FileUtility {

  struct RenameFlags: OptionSet {

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public let rawValue: UInt32

    /// On file systems that support it (see getattrlist(2) VOL_CAP_INT_RENAME_SWAP), it will cause the source and target to be atomically swapped.  Source and target need not be of the same type, i.e. it is possible to swap a file with a directory.  EINVAL is returned in case of bitwise-inclusive OR with RENAME_EXCL.
    public static var swap: Self {
      #if canImport(Darwin)
      return .init(rawValue: numericCast(RENAME_SWAP))
      #else
      return .init(rawValue: numericCast(RENAME_EXCHANGE))
      #endif
    }

    @available(*, unavailable, renamed: "swap")
    public static var exchange: Self { .swap }

    /// On file systems that support it (see getattrlist(2) VOL_CAP_INT_RENAME_EXCL), it will cause EEXIST to be returned if the destination already exists. EINVAL is returned in case of bitwise-inclusive OR with RENAME_SWAP.
    public static var exclisive: Self {
      #if canImport(Darwin)
      return .init(rawValue: numericCast(RENAME_EXCL))
      #else
      return .init(rawValue: numericCast(RENAME_NOREPLACE))
      #endif
    }

    @available(*, unavailable, renamed: "exclisive")
    public static var noReplace: Self { .exclisive }

  }

  /// The rename() system call causes the link named old to be renamed as new.  If new exists, it is first removed.  Both old and new must be of the same type (that is, both must be either directories or non-directories) and must reside on the same file system.
  /// - Parameters:
  ///   - path: src path
  ///   - fd: src path relative opened directory fd
  ///   - newPath: dst path
  ///   - tofd: dst path relative opened directory fd
  static func rename(_ src: FilePathOption, to dst: FilePathOption) throws {
    try _rename(src, to: dst).get()
  }

  @usableFromInline
  internal static func _rename(_ src: FilePathOption, to dst: FilePathOption) -> Result<Void, Errno> {
    assert(!src.path.isEmpty)
    assert(!dst.path.isEmpty)
    return nothingOrErrno(retryOnInterrupt: false) {
      src.path.withPlatformString { old in
        dst.path.withPlatformString { new in
          renameat(src.relativedDirFD.rawValue, old, dst.relativedDirFD.rawValue, new)
        }
      }
    }
  }

  #if canImport(Darwin)
  @available(macOS 10.12, *)
  static func rename(_ src: FilePathOption, to dst: FilePathOption, flags: RenameFlags) throws {
    assert(!src.path.isEmpty)
    assert(!dst.path.isEmpty)
    try nothingOrErrno(retryOnInterrupt: false) {
      src.path.withPlatformString { old in
        dst.path.withPlatformString { new -> Int32 in
          renameatx_np(src.relativedDirFD.rawValue, old, dst.relativedDirFD.rawValue, new, flags.rawValue)
        }
      }
    }.get()
  }
  #endif
}

// MARK: cwd
public extension FileUtility {
  static var currentDirectoryPath: FilePath {
    let path = getcwd(nil, 0)!
    defer {
      free(path)
    }
    return .init(platformString: path)
  }

  static func changeCurrentDirectoryPath(_ path: FilePath) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      path.withPlatformString { path in
        chdir(path)
      }
    }.get()
  }

  static func changeCurrentDirectoryPath(_ fd: FileDescriptor) throws {
    try nothingOrErrno(retryOnInterrupt: false) {
      fchdir(fd.rawValue)
    }.get()
  }
}
