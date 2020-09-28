import Foundation
import TuistCore
import TuistAutomation
import TSCBasic
import RxSwift
import XCTest

@testable import TuistAutomationTesting
@testable import TuistCoreTesting
@testable import TuistSupportTesting
@testable import TuistKit

final class TestServiceTests: TuistUnitTestCase {
    private var subject: TestService!
    private var projectGenerator: MockProjectGenerator!
    private var xcodebuildController: MockXcodeBuildController!
    private var buildGraphInspector: MockBuildGraphInspector!
    private var simulatorController: MockSimulatorController!
    
    override func setUp() {
        super.setUp()
        projectGenerator = .init()
        xcodebuildController = .init()
        buildGraphInspector = .init()
        simulatorController = .init()
        
        subject = TestService(
            projectGenerator: projectGenerator,
            xcodebuildController: xcodebuildController,
            buildGraphInspector: buildGraphInspector,
            simulatorController: simulatorController
        )
    }
    
    override func tearDown() {
        projectGenerator = nil
        xcodebuildController = nil
        buildGraphInspector = nil
        simulatorController = nil
        subject = nil
        super.tearDown()
    }
    
    func test_run_when_the_project_is_already_generated() throws {
        // Given
        let path = try temporaryPath()
        let workspacePath = path.appending(component: "App.xcworkspace")
        let graph = Graph.test()
        let scheme = Scheme.test()
        let target = Target.test()
        let buildArguments: [XcodeBuildArgument] = [.sdk("iphoneos")]
        
        projectGenerator.loadStub = { _path in
            XCTAssertEqual(_path, path)
            return graph
        }
        buildGraphInspector.testableSchemesStub = { _ in
            [scheme]
        }
        buildGraphInspector.testableTargetStub = { _scheme, _ in
            XCTAssertEqual(_scheme, scheme)
            return target
        }
        buildGraphInspector.workspacePathStub = { _path in
            XCTAssertEqual(_path, path)
            return workspacePath
        }
        buildGraphInspector.buildArgumentsStub = { _target, _ in
            XCTAssertEqual(_target, target)
            return buildArguments
        }
        
        let availableDevice: SimulatorDevice = .test()
        simulatorController.findAvailableDeviceStub = { _, _, _ in
            .just(availableDevice)
        }
        xcodebuildController.testStub = { _target, _scheme, _clean, _destination, _arguments in
            XCTAssertEqual(_target, .workspace(workspacePath))
            XCTAssertEqual(_scheme, scheme.name)
            XCTAssertTrue(_clean)
            XCTAssertEqual(_arguments, buildArguments)
            XCTAssertEqual(_destination, .device(availableDevice.udid))
            return Observable.just(.standardOutput(.init(raw: "success", formatted: nil)))
        }
        
        // Then
        try subject.testRun(
            schemeName: scheme.name,
            clean: true,
            path: path
        )
    }
    
    func test_run_only_cleans_the_first_time() throws {
        // Given
        let path = try temporaryPath()
        let workspacePath = path.appending(component: "App.xcworkspace")
        let graph = Graph.test()
        let schemeA = Scheme.test(name: "A")
        let schemeB = Scheme.test(name: "B")
        let targetA = Target.test(name: "A")
        let targetB = Target.test(name: "B")
        let buildArguments: [XcodeBuildArgument] = [.sdk("iphoneos")]
        
        projectGenerator.loadStub = { _path in
            XCTAssertEqual(_path, path)
            return graph
        }
        buildGraphInspector.buildableSchemesStub = { _ in
            [schemeA, schemeB]
        }
        buildGraphInspector.buildableTargetStub = { _scheme, _ in
            if _scheme == schemeA { return targetA }
            else if _scheme == schemeB { return targetB }
            else { XCTFail("unexpected scheme"); return targetA }
        }
        buildGraphInspector.workspacePathStub = { _path in
            XCTAssertEqual(_path, path)
            return workspacePath
        }
        buildGraphInspector.buildArgumentsStub = { _, _ in
            buildArguments
        }
        xcodebuildController.testStub = { _target, _scheme, _clean, _destination, _arguments in
            XCTAssertEqual(_target, .workspace(workspacePath))
            XCTAssertEqual(_arguments, buildArguments)
            
            if _scheme == "A" {
                XCTAssertEqual(_scheme, "A")
                XCTAssertTrue(_clean)
            } else if _scheme == "B" {
                // When running the second scheme clean should be false
                XCTAssertEqual(_scheme, "B")
                XCTAssertFalse(_clean)
            } else {
                XCTFail("unexpected scheme \(_scheme)")
            }
            return Observable.just(.standardOutput(.init(raw: "success", formatted: nil)))
        }
        
        // Then
        try subject.testRun(
            path: path
        )
    }
    
    func test_run_lists_schemes() throws {
        // Given
        let path = try temporaryPath()
        let workspacePath = path.appending(component: "App.xcworkspace")
        let graph = Graph.test()
        let schemeA = Scheme.test(name: "A")
        let schemeB = Scheme.test(name: "B")
        projectGenerator.loadStub = { _path in
            XCTAssertEqual(_path, path)
            return graph
        }
        buildGraphInspector.workspacePathStub = { _path in
            XCTAssertEqual(_path, path)
            return workspacePath
        }
        buildGraphInspector.testableSchemesStub = { _ in
            [
                schemeA,
                schemeB,
            ]
        }
        xcodebuildController.testStub = { _, _, _, _, _ in
            .just(.standardOutput(.init(raw: "success", formatted: nil)))
        }
        
        // When
        try subject.testRun(
            path: path
        )
        
        // Then
        XCTAssertPrinterContains("Found the following testable schemes: A, B", at: .debug, ==)
    }
}

// MARK: - Helpers

private extension TestService {
    func testRun(
        schemeName: String? = nil,
        generate: Bool = false,
        clean: Bool = false,
        configuration: String? = nil,
        path: AbsolutePath,
        deviceName: String? = nil,
        osVersion: String? = nil
    ) throws {
        try run(
            schemeName: schemeName,
            generate: generate,
            clean: clean,
            configuration: configuration,
            path: path,
            deviceName: deviceName,
            osVersion: osVersion
        )
    }
}