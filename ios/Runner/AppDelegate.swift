import Flutter
import EventKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CalendarBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "br.com.netherland.cwsadmixcontrol/calendar",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "createEvent" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.createCalendarEvent(call: call, result: result)
    }
  }

  private func createCalendarEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let title = args["title"] as? String,
      let notes = args["notes"] as? String,
      let startMillis = (args["startMillis"] as? NSNumber)?.doubleValue,
      let endMillis = (args["endMillis"] as? NSNumber)?.doubleValue
    else {
      result(FlutterError(
        code: "invalid_calendar_event",
        message: "Dados do evento de calendario invalidos.",
        details: nil
      ))
      return
    }

    let alarmOffset = (args["alarmOffsetSeconds"] as? NSNumber)?.doubleValue ?? -86400

    requestCalendarAccess { [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self = self else { return }

        if let error = error {
          result(FlutterError(
            code: "calendar_access_error",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }

        guard granted else {
          result(FlutterError(
            code: "calendar_permission_denied",
            message: "Permissao para criar evento no Calendario negada.",
            details: nil
          ))
          return
        }

        guard let calendar = self.eventStore.defaultCalendarForNewEvents else {
          result(FlutterError(
            code: "calendar_unavailable",
            message: "Nenhum calendario disponivel para novos eventos.",
            details: nil
          ))
          return
        }

        let event = EKEvent(eventStore: self.eventStore)
        event.title = title
        event.notes = notes
        event.startDate = Date(timeIntervalSince1970: startMillis / 1000)
        event.endDate = Date(timeIntervalSince1970: endMillis / 1000)
        event.calendar = calendar
        event.addAlarm(EKAlarm(relativeOffset: alarmOffset))

        do {
          try self.eventStore.save(event, span: .thisEvent, commit: true)
          result(nil)
        } catch {
          result(FlutterError(
            code: "calendar_save_error",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func requestCalendarAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestWriteOnlyAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }
}
