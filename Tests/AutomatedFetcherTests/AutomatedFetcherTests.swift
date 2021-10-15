import XCTest
import Combine
@testable import AutomatedFetcher

var cancellables = Set<AnyCancellable>()

class MyNetworkFether {
    let value = CurrentValueSubject<String,Never>("")
    let fetcher:AutomatedFetcher<String>
    var cancellables = Set<AnyCancellable>()
    init() {
        fetcher = AutomatedFetcher<String>(value, isOn: true, timeInterval: 20)
        fetcher.triggered.sink { [weak self] in
            self?.fetch()
        }.store(in: &cancellables)
    }
    func fetch() {
        fetcher.started()
        URLSession.shared.dataTaskPublisher(for: URL(string: "https://www.tietoevry.com")!)
            .map { $0.data }
            .tryMap { data -> String in
                guard let value = String(data: data,encoding:.utf8) else {
                    throw URLError(.unknown)
                }
                return value
            }.sink { [weak self] compl in
                switch compl {
                case .failure(let error):
                    debugPrint(error)
                    self?.fetcher.failed()
                case .finished: break;
                }
            } receiveValue: { [weak self] value in
                self?.value.send(value)
                self?.fetcher.completed()
            }.store(in: &cancellables)
    }
}
final class AutomatedFetcherTests: XCTestCase {
    func testSubscriptionFetch() {
        let expectation = XCTestExpectation(description: "testFetcher")
        
        var currentValue = "Start"
        let value = CurrentValueSubject<String,Never>(currentValue)
        
        let fetcher = AutomatedFetcher<String>(value, isOn: true, timeInterval: 10)
        
        fetcher.triggered.sink {
            currentValue = "End"
            value.send(currentValue)
        }.store(in: &cancellables)
        
        value.sink { value in
            XCTAssert(currentValue == value)
            if value == "End" {
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 2.0)
    }
    func testTimerFetch() {
        let expectation = XCTestExpectation(description: "testTimerFetch")
        let currentValue = "Start"
        let value = CurrentValueSubject<String,Never>(currentValue)
        let fetcher = AutomatedFetcher<String>(value, isOn: true, timeInterval: 0.5)
        
        fetcher.triggered.sink {
            expectation.fulfill()
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 2.0)
    }
    func testNoSubscribers() {
        let expectation = XCTestExpectation(description: "testNoSubscribers")
        let currentValue = "Start"
        let value = CurrentValueSubject<String,Never>(currentValue)
        let fetcher = AutomatedFetcher<String>(value, isOn: true, timeInterval: 10)
        
        fetcher.triggered.sink {
            XCTFail("Should not have triggered")
        }.store(in: &cancellables)
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { timer in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    func testExampleClass() {
        let expectation = XCTestExpectation(description: "testExampleClass")
        let f = MyNetworkFether()
        f.value.sink { string in
            expectation.fulfill()
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 10.0)
    }
}
