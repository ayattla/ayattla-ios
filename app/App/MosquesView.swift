import SwiftUI
import MapKit
import AyatDesign

/// Nearby mosques (site: /tools/nearby-mosques — radius 1/3/5 km, "حدد موقعي وابحث").
/// Search runs on the device with MapKit; nothing is sent to our server.
struct MosquesView: View {
    struct Mosque: Identifiable, Equatable {
        let id: String
        let name: String
        let address: String?
        let coordinate: CLLocationCoordinate2D
        var distance: Double = 0
        var item: MKMapItem?

        static func == (a: Mosque, b: Mosque) -> Bool { a.id == b.id && a.distance == b.distance }
    }

    enum Phase: Equatable { case idle, searching, done, failed }

    static let radii = [1, 3, 5]
    static let maxPins = 12

    @AppStorage("mosques.radius") private var radiusKm = 3
    @State private var location = LocationService()
    @State private var phase = Phase.idle
    @State private var mosques: [Mosque] = []
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var searchedAt: CLLocationCoordinate2D?

    var body: some View {
        List {
Group {
            Section {
                Picker("نصف القطر", selection: $radiusKm) {
                    ForEach(Self.radii, id: \.self) { Text("\(Num.int($0)) كم").tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Button {
                    locate()
                } label: {
                    Label("حدد موقعي وابحث", systemImage: "location.fill")
                        .font(.ui(.headline)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Brand.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(phase == .searching)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
            }

            content
        
}.listRowBackground(Brand.surface)
}
        .brandScreen()
        .navigationTitle("المساجد القريبة")
        .onAppear {
            if location.status == .authorizedWhenInUse || location.status == .authorizedAlways { locate() }
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            if let c = location.coordinate { Task { await search(around: c) } }
        }
        .onChange(of: location.failed) { _, failed in if failed && phase == .searching { phase = .failed } }
        .onChange(of: radiusKm) { _, _ in
            if let c = searchedAt { Task { await search(around: c) } }
        }
    }

    @ViewBuilder private var content: some View {
        if location.denied {
            ContentUnavailableView {
                Label("الموقع غير مسموح", systemImage: "location.slash")
            } description: {
                Text("اسمح للتطبيق بالوصول إلى موقعك من الإعدادات لعرض المساجد القريبة منك")
            } actions: {
                Button("فتح الإعدادات") { openSystemSettings() }
            }
        } else {
            switch phase {
            case .idle:
                Text("اختر نصف القطر ثم اضغط «حدد موقعي وابحث». يتم البحث على جهازك عبر خرائط Apple.")
                    .font(.ui(.footnote)).foregroundStyle(.secondary)
            case .searching:
                HStack { Spacer(); ProgressView("جار البحث"); Spacer() }.frame(minHeight: 120)
            case .failed:
                ContentUnavailableView {
                    Label("تعذر البحث", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("تحقق من الاتصال بالإنترنت وخدمات الموقع ثم حاول مرة أخرى")
                } actions: {
                    Button("إعادة المحاولة") { locate() }
                }
            case .done where mosques.isEmpty:
                ContentUnavailableView {
                    Label("لا توجد مساجد ضمن \(Num.int(radiusKm)) كم", systemImage: "mappin.slash")
                } description: {
                    Text(radiusKm < 5 ? "جرب نصف قطر أكبر" : "لم تعثر الخرائط على مساجد قريبة من موقعك")
                }
            case .done:
                Section {
                    map.frame(height: 240).listRowInsets(EdgeInsets())
                }
                Section("\(Self.countText(mosques.count)) ضمن \(Num.int(radiusKm)) كم") {
                    ForEach(mosques) { m in row(m) }
                }
            }
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            // Nearest only: dozens of pins on a 240pt map are unreadable; the full list is below.
            ForEach(mosques.prefix(Self.maxPins)) { m in
                Marker(m.name, systemImage: "building.columns", coordinate: m.coordinate).tint(Brand.primary)
            }
        }
        .mapControls { MapUserLocationButton() }
        .accessibilityLabel("خريطة المساجد القريبة")
    }

    private func row(_ m: Mosque) -> some View {
        Button {
            m.item?.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "building.columns").foregroundStyle(Brand.primary)
                    .frame(width: 32, height: 32).background(Brand.tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.name).foregroundStyle(.primary)
                    if let a = m.address { Text(a).font(.ui(.caption)).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer()
                Text(Num.distance(meters: m.distance)).font(.ui(.subheadline).monospacedDigit())
                    .foregroundStyle(Brand.primaryInk)
            }
            .frame(minHeight: Brand.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("يفتح الاتجاهات في الخرائط")
    }

    private func locate() {
        phase = .searching
        if let c = location.coordinate {
            Task { await search(around: c) }
        }
        location.requestLocation()
    }

    @MainActor private func search(around c: CLLocationCoordinate2D) async {
        phase = .searching
        searchedAt = c
        let meters = Double(radiusKm) * 1000
        let region = MKCoordinateRegion(center: c, latitudinalMeters: meters * 2, longitudinalMeters: meters * 2)
        var found: [Mosque] = []
        var anySucceeded = false
        // Two queries: Arabic and English names are indexed separately in Apple Maps.
        for q in ["مسجد", "mosque"] {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = q
            req.region = region
            req.resultTypes = .pointOfInterest
            guard let resp = try? await MKLocalSearch(request: req).start() else { continue }
            anySucceeded = true
            found += resp.mapItems.map { item in
                let p = item.placemark.coordinate
                return Mosque(id: "\(item.name ?? "")|\(Int(p.latitude * 1e4))|\(Int(p.longitude * 1e4))",
                              name: item.name ?? "مسجد", address: Self.shortAddress(item.placemark),
                              coordinate: p, item: item)
            }
        }
        guard anySucceeded else { phase = .failed; return }
        mosques = Self.nearby(found, from: c, radiusKm: radiusKm)
        camera = .region(region)
        phase = .done
    }

    /// Street and district only — no postcode, building code or country (they truncate on a phone).
    static func shortAddress(_ p: MKPlacemark) -> String? {
        let parts = [p.thoroughfare, p.subLocality ?? p.locality].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "، ")
    }

    /// "مسجد واحد"، "مسجدان"، "٣ مساجد"، "١١ مسجدا".
    static func countText(_ n: Int) -> String {
        switch n {
        case 1: "مسجد واحد"
        case 2: "مسجدان"
        case 3...10: "\(Num.int(n)) مساجد"
        default: "\(Num.int(n)) مسجدا"
        }
    }

    /// Keeps results within the radius, drops duplicates from the two queries, nearest first.
    static func nearby(_ items: [Mosque], from c: CLLocationCoordinate2D, radiusKm: Int) -> [Mosque] {
        let origin = CLLocation(latitude: c.latitude, longitude: c.longitude)
        var seen = Set<String>()
        return items.compactMap { m -> Mosque? in
            guard seen.insert(m.id).inserted else { return nil }
            var m = m
            m.distance = origin.distance(from: CLLocation(latitude: m.coordinate.latitude, longitude: m.coordinate.longitude))
            return m.distance <= Double(radiusKm) * 1000 ? m : nil
        }
        .sorted { $0.distance < $1.distance }
    }
}

func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}
