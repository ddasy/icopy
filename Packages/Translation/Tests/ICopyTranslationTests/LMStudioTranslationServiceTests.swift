import Foundation
import ICopyCore
import ICopyTranslation
import Testing

@Suite(.serialized)
struct LMStudioTranslationServiceTests {
    @Test
    func parsesSuccessfulChatCompletion() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/v1/chat/completions")
            #expect(request.httpMethod == "POST")
            let data = #"{"choices":[{"message":{"role":"assistant","content":" Hello "}}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = LMStudioTranslationService(config: .default, session: Self.stubbedSession())

        let result = try await service.translate("你好", to: .english)

        #expect(result == "Hello")
    }

    @Test
    func reportsServerErrors() async throws {
        StubURLProtocol.handler = { request in
            let data = #"{"error":"bad"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = LMStudioTranslationService(config: .default, session: Self.stubbedSession())

        await #expect(throws: TranslationError.server(status: 500, body: #"{"error":"bad"}"#)) {
            _ = try await service.translate("hello", to: .chinese)
        }
    }

    @Test
    func reportsMalformedResponses() async throws {
        StubURLProtocol.handler = { request in
            let data = #"{"choices":[]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = LMStudioTranslationService(config: .default, session: Self.stubbedSession())

        await #expect(throws: TranslationError.malformedResponse) {
            _ = try await service.translate("hello", to: .chinese)
        }
    }

    @Test
    func rejectsEmptyInput() async {
        let service = LMStudioTranslationService(config: .default, session: Self.stubbedSession())

        await #expect(throws: TranslationError.emptyInput) {
            _ = try await service.translate("   ", to: .english)
        }
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) = { _ in
        throw TranslationError.transport("No handler")
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
