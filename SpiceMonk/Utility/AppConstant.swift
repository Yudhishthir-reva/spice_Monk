//
//  AppConstant.swift
//  SpiceMonk
//

import Foundation

/// The only switch. Every per-environment value (API host, payment page origin) is derived from
/// it on `RequestEnvironmentType`, so this line is the whole change.
let currentEnvironment: RequestEnvironmentType = .production

let kDateFormatterHHMMA: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "hh:mm a"
    return dateFormatter
}()

let kDateFormatterDDMMYYYY: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    return dateFormatter
}()

let kDateFormatterDDMMYYYYss: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter
}()
