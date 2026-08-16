//
//  AppConstant.swift
//  SpiceMonk
//

import Foundation

let currentEnvironment: RequestEnvironmentType = .stagging

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
