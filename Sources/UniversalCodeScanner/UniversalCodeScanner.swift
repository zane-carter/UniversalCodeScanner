//
//  UniversalCodeScanner.swift
//  Forked and Modified based on `CodeScanner` by Paul Hudson
//
//  Created by Zane Carter on 21/12/20.
//


import SwiftUI
import AVFoundation

public struct UniversalScannerView: UIViewControllerRepresentable {
    
    public enum ScanError: Error {
        case badInput, badOutput
    }
    
    public enum ScanMode {
        case once, oncePerCode, continuous
    }

    public class ScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: UniversalScannerView
        var codesFound: Set<String>
        var isFinishScanning = false
        var lastTime = Date(timeIntervalSince1970: 0)

        init(parent: UniversalScannerView) {
            self.parent = parent
            self.codesFound = Set<String>()
            
            
        }

        public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                let type = readableObject.type
                
                guard let stringValue = readableObject.stringValue else { return }
                guard isFinishScanning == false else { return }

                switch self.parent.scanMode {
                case .once:
                    found(type: type, code: stringValue)
                    // make sure we only trigger scan once per use
                    isFinishScanning = true
                case .oncePerCode:
                    if !codesFound.contains(stringValue) {
                        codesFound.insert(stringValue)
                        found(type: type, code: stringValue)
                    }
                case .continuous:
                    if isPastScanInterval() {
                        found(type: type, code: stringValue)
                    }
                }
            }
        }

        func isPastScanInterval() -> Bool {
            return Date().timeIntervalSince(lastTime) >= self.parent.scanInterval
        }
        
        func found(type: AVMetadataObject.ObjectType, code: String) {
            lastTime = Date()
            parent.completion(.success((type, code)))
        }

        func didFail(reason: ScanError) {
            parent.completion(.failure(reason))
        }
    }

    public class ScannerViewController: UIViewController {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        var delegate: ScannerCoordinator?

        override public func viewDidLoad() {
            super.viewDidLoad()


            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(updateOrientation),
                                                   name: Notification.Name("UIDeviceOrientationDidChangeNotification"),
                                                   object: nil)

            view.backgroundColor = UIColor.black
            captureSession = AVCaptureSession()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
            let videoInput: AVCaptureDeviceInput

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                return
            }

            if (captureSession.canAddInput(videoInput)) {
                captureSession.addInput(videoInput)
            } else {
                delegate?.didFail(reason: .badInput)
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if (captureSession.canAddOutput(metadataOutput)) {
                captureSession.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
                
                let invalidObjects: [AVMetadataObject.ObjectType] = [.humanBody, .dogBody, .catBody, .face]
                metadataOutput.metadataObjectTypes.removeAll(where: {invalidObjects.contains($0)})
                
            } else {
                delegate?.didFail(reason: .badOutput)
                return
            }
        }

        override public func viewWillLayoutSubviews() {
            previewLayer?.frame = view.layer.bounds
        }

        @objc func updateOrientation() {
            guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else { return }
            guard let connection = captureSession.connections.last, connection.isVideoOrientationSupported else { return }
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue) ?? .portrait
        }

        override public func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateOrientation()
        }

        override public func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            
            if previewLayer == nil {
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            }
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            if (captureSession?.isRunning == false) {
                captureSession.startRunning()
            }
        }

        override public func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)

            if (captureSession?.isRunning == true) {
                captureSession.stopRunning()
            }

            NotificationCenter.default.removeObserver(self)
        }

        override public var prefersStatusBarHidden: Bool {
            return true
        }

        override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return .all
        }
    }

    public let codeTypes: [AVMetadataObject.ObjectType]
    public let scanMode: ScanMode
    public let scanInterval: Double
    public var simulatedData = ""
    public var completion: (Result<(AVMetadataObject.ObjectType, String), ScanError>) -> Void

    public init(scanMode: ScanMode = .once, scanInterval: Double = 2.0, simulatedData: String = "", completion: @escaping (Result<(AVMetadataObject.ObjectType, String), ScanError>) -> Void) {
        self.codeTypes = []
        self.scanMode = scanMode
        self.scanInterval = scanInterval
        self.simulatedData = simulatedData
        self.completion = completion
        
        
    }

    public func makeCoordinator() -> ScannerCoordinator {
        return ScannerCoordinator(parent: self)
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {

    }
}
