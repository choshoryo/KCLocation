//
//  LocationTool.swift
//  LocationTool
//
//  
//  Copyright © 2016年 zero. All rights reserved.
//

import UIKit
import CoreLocation

// 创建工具类
// 接口的类型
// 接口的名称
// 接口的参数
// 返回值

// 返回给外界参数的闭包
typealias ResultBlock = (location : CLLocation?, error : String?) -> Void

class LocationTool: NSObject {
    
    // MARK:- 单例对象
    static let sharedInstance = LocationTool()
    
    // MARK:- 懒加载
    private lazy var locationMgr : CLLocationManager = {
        let locationMgr = CLLocationManager()
        
        locationMgr.delegate = self
        
        // 配置定位管理者
        guard #available(iOS 8.0, *) else {return locationMgr} // iOS 8.0之前不需要做额外配置
        
        // 获取info.plist
        let infoDict = NSBundle.mainBundle().infoDictionary!
        
        // NSLocationAlwaysUsageDescription
        // NSLocationWhenInUseUsageDescription
        // 查看对应的key
//        print(infoDict)
        
        // 取出前后台定位授权的key的值
        let alwaysUsage = infoDict["NSLocationAlwaysUsageDescription"]
        // 取出前台定位授权的key的值
        let whenInUseUsage = infoDict["NSLocationWhenInUseUsageDescription"]
        
        // 判断：
        // 如果两个key的value都有值,那么使用前后台定位授权(权限大)
        // 如果只有一个key的value有值,那么就使用对应的定位授权
        // 如果两个key的value都没有值,给开发者提示,填写对应的key
        // 总结：先判断前后台，再判断后台
        guard alwaysUsage == nil else { // 判断是否前后台授权
            locationMgr.requestAlwaysAuthorization()
            return locationMgr
        }
        
        guard whenInUseUsage == nil else { // 判断是否前台授权
            locationMgr.requestWhenInUseAuthorization()
            
            // 判断开发者是否勾选了后台模式
            let backgroundModes = infoDict["UIBackgroundModes"] as! [String]
            if backgroundModes.contains("location") { // 选择后台模式
                // iOS9.0：在前台定位授权下，如果开启了后台模式，必须允许后台定位
                if #available(iOS 9.0, *) {
                    locationMgr.allowsBackgroundLocationUpdates = true
                }
                
            } else {
                print("在前台定位授权的情况下,如果想要在后台也获取用户的位置信息,必须勾选后台模式,location updates")
            }
            
            return locationMgr
        }
        
        print("在iOS8.0之后,如果想要获取用户的位置,必须请求定位授权,\n在info.plist中配置对应的key NSLocationAlwaysUsageDescription 或者 NSLocationWhenInUseUsageDescription")

        return locationMgr
    }()
    
    // MARK:- 属性
    private var result : ResultBlock?
    
    // MARK:- 接口
    func getCurrentLocation(result : ResultBlock) {
        // 记录闭包信息
        self.result = result
        
        // 发送定位请求
        locationMgr.requestLocation()
    }
    
}

// MARK:- CLLocationManagerDelegate
extension LocationTool : CLLocationManagerDelegate {
    /**
     当获取到用户的位置信息时会调用该方法
     
     - parameter manager:   位置管理者
     - parameter locations: 位置数组
     */
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        // 在位置数组中,最后一个是最新的
        // 取出位置
        guard let location = locations.last else {
            if let result = result {
                result(location: nil, error: "未能获取到地理信息")
            }
            return
        }
        
        // 判断位置是否可以用
        guard location.horizontalAccuracy >= 0 else {return}
        
        // 返回位置信息
        if let result = result {
            result(location: location, error: nil)
        }
        
    }
    
    /**
     当授权状态改变的时候会调用该方法
     
     - parameter manager: 位置管理者
     - parameter status:  授权状态
     */
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        // 判断闭包是否为空
        guard let result = result else {return}
        
        // 根据不同的定位情况给外界返回消息
        switch status {
        case .NotDetermined:
            result(location: nil, error: "用户未决定")
        case .Restricted:
            result(location: nil, error: "受系统限制")
        case .Denied:
            if CLLocationManager.locationServicesEnabled() {
                
                result(location: nil, error: "用户真正拒绝")
                
                // 如果定位服务开启,用户拒绝了,系统不会自动弹框,需要手动给用户提示
                if #available(iOS 8.0, *) {
                    let settingURL = NSURL(string: UIApplicationOpenSettingsURLString)!
                    if UIApplication.sharedApplication().canOpenURL(settingURL) {
                        UIApplication.sharedApplication().openURL(settingURL)
                    }
                } else {
                    // 准备多张图片,引导用户去设置界面允许定位
                }
            } else {
                result(location: nil, error: "定位服务未开启")
                // 如果定位服务关闭,用户下次再打开时,系统会自动弹框,让用户去设置界面打开定位服务
            }
        case .AuthorizedAlways:
            print("前后台授权")
        case .AuthorizedWhenInUse:
            print("前台授权")
        }
        
    }
    
    /**
     当定位请求失败的时候会调用该方法
     
     - parameter manager: 位置管理者
     - parameter error : 错误信息
     */
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        
        // 判断闭包是否为空
        guard let result = result else {return}
        
        result(location: nil, error: "无法定位")
}
}