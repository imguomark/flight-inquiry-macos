// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlightInquiry",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FlightInquiryApp", targets: ["FlightInquiryApp"]),
        .library(name: "FlightInquiryCore", targets: ["FlightInquiryCore"])
    ],
    targets: [
        .target(name: "FlightInquiryCore"),
        .executableTarget(name: "FlightInquiryApp", dependencies: ["FlightInquiryCore"]),
        .testTarget(name: "FlightInquiryCoreTests", dependencies: ["FlightInquiryCore"])
    ]
)
