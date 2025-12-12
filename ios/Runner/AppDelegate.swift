import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 🔍 LOGS DETALHADOS PARA DEBUG
    let deviceModel = UIDevice.current.model  // "iPhone" ou "iPad"
    let systemVersion = UIDevice.current.systemVersion
    let screenSize = UIScreen.main.bounds.size
    
    print("📱 ===== APP INICIANDO =====")
    print("📱 Device: \(deviceModel)")
    print("📱 iOS Version: \(systemVersion)")
    print("📱 Screen: \(screenSize.width)x\(screenSize.height)")
    
    // 🔍 VERIFICAR GOOGLESERVICE-INFO.PLIST
    if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
      print("✅ GoogleService-Info.plist found at: \(plistPath)")
      
      // Ler conteúdo para validar
      if let plistData = FileManager.default.contents(atPath: plistPath),
         let plistDict = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
        
        if let bundleId = plistDict["BUNDLE_ID"] as? String {
          print("✅ Bundle ID: \(bundleId)")
        }
        
        if let projectId = plistDict["PROJECT_ID"] as? String {
          print("✅ Project ID: \(projectId)")
        }
      }
    } else {
      print("❌ GoogleService-Info.plist NOT FOUND!")
      print("❌ Bundle path: \(Bundle.main.bundlePath)")
      
      // Listar todos os plists disponíveis
      if let contents = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
        let plists = contents.filter { $0.hasSuffix(".plist") }
        print("❌ Available plists: \(plists)")
      }
    }
    
    // 🔥 CONFIGURAR FIREBASE COM PROTEÇÃO
    do {
      if FirebaseApp.app() == nil {
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
      } else {
        print("ℹ️ Firebase already configured")
      }
    } catch let error as NSError {
      print("❌ ===== FIREBASE ERROR =====")
      print("❌ Code: \(error.code)")
      print("❌ Domain: \(error.domain)")
      print("❌ Description: \(error.localizedDescription)")
      print("❌ User Info: \(error.userInfo)")
      
      // 🚨 NO iOS, NÃO CRASHAR - Apenas registrar erro
      // O app vai continuar sem Firebase (melhor que crashar)
      #if DEBUG
      // Em desenvolvimento, mostrar alerta após 1 segundo
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        if let rootVC = self.window?.rootViewController {
          let alert = UIAlertController(
            title: "Firebase Error (\(deviceModel))",
            message: "Error: \(error.localizedDescription)\n\nCheck Xcode console for details.",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "OK", style: .default))
          rootVC.present(alert, animated: true)
        }
      }
      #endif
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
