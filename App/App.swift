// A one-screen MapKit lab. Each launch draws ONE map variant, chosen by launch arguments, so a CI
// runner can screenshot every variant in the iOS Simulator:
//   -style standard|realistic|muted|hybrid|imagery
//   -poi all|travel|none
//   -lat 30.0571 -lng 31.2243 -span 0.02   (span in degrees; 120 = whole globe)
//   -pitch 0..60  -heading 0..360
//   -sheet 0|1   (a 320 pt bottom panel over the map, like the app's place sheet)
//   -legalInset 0|1  (lift Apple's logo/Legal above that panel)
import MapKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let w = UIWindow(frame: UIScreen.main.bounds)
    w.rootViewController = MapViewController()
    w.makeKeyAndVisible()
    window = w
    return true
  }
}

private func arg(_ name: String, _ fallback: String) -> String {
  let a = ProcessInfo.processInfo.arguments
  if let i = a.firstIndex(of: "-" + name), i + 1 < a.count { return a[i + 1] }
  return fallback
}

final class MapViewController: UIViewController {
  private let map = MKMapView()

  private var travel: [MKPointOfInterestCategory] {
    var c: [MKPointOfInterestCategory] = [
      .museum, .park, .nationalPark, .beach, .restaurant, .cafe, .bakery, .brewery, .winery,
      .nightlife, .hotel, .theater, .zoo, .aquarium, .amusementPark, .stadium, .marina,
    ]
    if #available(iOS 18.0, *) {
      c += [.landmark, .nationalMonument, .castle, .fortress, .spa, .musicVenue, .planetarium, .distillery]
    }
    return c
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    map.frame = view.bounds
    map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(map)

    let poi: MKPointOfInterestFilter
    switch arg("poi", "all") {
    case "travel": poi = MKPointOfInterestFilter(including: travel)
    case "none": poi = .excludingAll
    default: poi = .includingAll
    }

    switch arg("style", "standard") {
    case "realistic":
      let c = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
      c.pointOfInterestFilter = poi
      map.preferredConfiguration = c
    case "muted":
      let c = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
      c.pointOfInterestFilter = poi
      map.preferredConfiguration = c
    case "hybrid":
      let c = MKHybridMapConfiguration(elevationStyle: .realistic)
      c.pointOfInterestFilter = poi
      map.preferredConfiguration = c
    case "legacy":
      // No configuration object at all: the plain MKMapView map type most apps use.
      map.mapType = .standard
      map.pointOfInterestFilter = poi
    case "flat":
      let c = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
      c.pointOfInterestFilter = poi
      map.preferredConfiguration = c
    case "imagery":
      map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
    default:
      let c = MKStandardMapConfiguration()
      c.pointOfInterestFilter = poi
      map.preferredConfiguration = c
    }
    map.showsCompass = true
    map.showsScale = false

    let lat = Double(arg("lat", "30.0571")) ?? 30.0571
    let lng = Double(arg("lng", "31.2243")) ?? 31.2243
    let span = Double(arg("span", "0.02")) ?? 0.02
    let pitch = Double(arg("pitch", "0")) ?? 0
    let heading = Double(arg("heading", "0")) ?? 0
    let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    if let dist = Double(arg("distance", "")) {
      // Camera distance in metres (globe test: ~20,000 km).
      map.setCamera(MKMapCamera(lookingAtCenter: centre, fromDistance: dist, pitch: CGFloat(pitch), heading: heading), animated: false)
    } else if span >= 60 {
      // Fully zoomed out: MapKit decides globe vs flat by the configuration.
      map.setRegion(MKCoordinateRegion(center: centre, span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 150)), animated: false)
    } else {
      let metres = span * 111_000
      let cam = MKMapCamera(lookingAtCenter: centre, fromDistance: metres * 2.2, pitch: CGFloat(pitch), heading: heading)
      map.setCamera(cam, animated: false)
    }

    if arg("sheet", "0") == "1" {
      let sheet = UIView()
      sheet.backgroundColor = UIColor(white: 0.98, alpha: 1)
      sheet.layer.cornerRadius = 20
      sheet.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(sheet)
      NSLayoutConstraint.activate([
        sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        sheet.heightAnchor.constraint(equalToConstant: 320),
      ])
      if arg("legalInset", "0") == "1" {
        // The public way to lift MapKit's attribution: the view's layout margins / safe area.
        map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 320, right: 0)
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 320 - view.safeAreaInsets.bottom, right: 0)
      }
    }

    let label = UILabel()
    label.text = ProcessInfo.processInfo.arguments.dropFirst().joined(separator: " ")
    label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
    label.backgroundColor = UIColor(white: 1, alpha: 0.8)
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
      label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
    ])
  }
}
