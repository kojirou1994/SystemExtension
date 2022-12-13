import SystemPackage
import SystemLibc
import CUtility

public enum Poll {
  public struct PollFD {
    private var rawValue: pollfd

    public init(fd: FileDescriptor, events: Events = []) {
      rawValue = .init(fd: fd.rawValue, events: events.rawValue, revents: 0)
    }

    public var fd: FileDescriptor {
      .init(rawValue: rawValue.fd)
    }

    public var events: Events {
      get {
        .init(rawValue: rawValue.events)
      }
      set {
        rawValue.events = newValue.rawValue
      }
    }

    public var returnedEvents: Events {
      .init(rawValue: rawValue.events)
    }

    public struct Events: OptionSet, MacroRawRepresentable {
      public init(rawValue: Int16) {
        self.rawValue = rawValue
      }

      public var rawValue: Int16

      @_alwaysEmitIntoClient
      public static var err: Self { .init(macroValue: POLLERR) }
      @_alwaysEmitIntoClient
      public static var hup: Self { .init(macroValue: POLLHUP) }
      /// any readable data available
      @_alwaysEmitIntoClient
      public static var `in`: Self { .init(macroValue: POLLIN) }
      @_alwaysEmitIntoClient
      public static var fdNotOpen: Self { .init(macroValue: POLLNVAL) }
      @_alwaysEmitIntoClient
      public static var out: Self { .init(macroValue: POLLOUT) }
      @_alwaysEmitIntoClient
      public static var highPriorityDataRead: Self { .init(macroValue: POLLPRI) }
      @_alwaysEmitIntoClient
      public static var priorityDataRead: Self { .init(macroValue: POLLRDBAND) }
      @_alwaysEmitIntoClient
      public static var normalDataRead: Self { .init(macroValue: POLLRDNORM) }
      @_alwaysEmitIntoClient
      public static var priorityDataWrite: Self { .init(macroValue: POLLWRBAND) }
      @_alwaysEmitIntoClient
      public static var normalDataWrite: Self { .init(macroValue: POLLWRNORM) }
    }
  }

  public struct Timeout {
    public init(milliseconds: Int32) {
      self.milliseconds = milliseconds
    }

    public var milliseconds: Int32

    @_alwaysEmitIntoClient
    public static var indefinite: Self { .init(milliseconds: -1) }
  }

  /// return nil if the time limit expires
  public static func call(fds: UnsafeMutableBufferPointer<PollFD>, timeout: Timeout) -> Result<FileDescriptor, Errno>? {
    let ret = poll(.init(OpaquePointer(fds.baseAddress)), numericCast(fds.count), timeout.milliseconds)
    switch ret {
    case -1: return .failure(.systemCurrent)
    case 0: return nil
    default: return .success(.init(rawValue: ret))
    }
  }
}
