import Combine
import Foundation

public class AutomatedFetcher<DataType:Any> : ObservableObject {
    private var subjectCancellable: AnyCancellable? = nil
    private var timerCancellable: AnyCancellable? = nil
    private var triggeredSubject = PassthroughSubject<Void,Never>()
    private var lastFetch:Date
    public let triggered:AnyPublisher<Void,Never>
    
    @Published public private(set) var fetching:Bool = false
    @Published public var isOn:Bool = true {
        didSet { configure() }
    }
    @Published public var timeInterval:TimeInterval {
        didSet { configure() }
    }
    public var shouldFetch:Bool {
        return fetching && lastFetch.timeIntervalSinceNow < timeInterval
    }
    
    public init(_ subject:CurrentValueSubject<DataType,Error>, lastFetch date:Date? = nil, isOn:Bool = true, timeInterval:TimeInterval = 60) {
        self.timeInterval = timeInterval
        self.isOn = isOn
        self.lastFetch = date ?? Date().addingTimeInterval(timeInterval * -1 - 1)
        triggered = triggeredSubject.eraseToAnyPublisher()
        configure()
        subjectCancellable = subject.handleEvents(receiveSubscription: subscriptionRecieved)
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    }
    public init(_ subject:CurrentValueSubject<DataType,Never>, lastFetch date:Date? = nil, isOn:Bool = true, timeInterval:TimeInterval = 60) {
        self.timeInterval = timeInterval
        self.isOn = isOn
        self.lastFetch = date ?? Date().addingTimeInterval(timeInterval * -1 - 1)
        triggered = triggeredSubject.eraseToAnyPublisher()
        configure()
        subjectCancellable = subject.handleEvents(receiveSubscription: subscriptionRecieved)
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    }
    private func subscriptionRecieved(_ sub: Subscription) {
        if self.isOn == true {
            self.triggeredSubject.send()
        }
    }
    public func started() {
        fetching = true
    }
    public func completed() {
        fetching = false
        lastFetch = Date()
    }
    public func failed() {
        fetching = false
    }
    private func configure() {
        timerCancellable?.cancel()
        timerCancellable = nil
        if isOn == false {
            return
        }
        timerCancellable = Timer.publish(every: timeInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.triggeredSubject.send()
            }
    }
}
