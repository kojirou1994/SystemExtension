import CUtility
import SystemLibc
import SystemPackage

public extension LazyCopiedCString {
  convenience init(format: UnsafePointer<CChar>, _ args: CVarArg...) throws {
    var size: Int32 = 0
    let cString = try safeInitialize { str in
      withVaList(args) { va in
        size = SystemLibc.vasprintf(&str, format, va)
      }
    }
    self.init(cString: cString, forceLength: Int(size), freeWhenDone: true)
  }
}

public extension FileStream {
  func write(format: UnsafePointer<CChar>, _ args: CVarArg...) -> Int32 {
    withVaList(args) { va in
      SystemLibc.vfprintf(rawValue, format, va)
    }
  }
}


public extension FileDescriptor {
  func write(format: UnsafePointer<CChar>, _ args: CVarArg...) -> Int32 {
    withVaList(args) { va in
      SystemLibc.vdprintf(rawValue, format, va)
    }
  }
}
