//  Copyright (c) Ely Deckers.
// 
//  This source code is licensed under the MPL-2.0 license found in the
//  LICENSE file in the root directory of this source tree.

import XCTest

import Embassy
import EnvoyAmbassador

import MimeParser

@testable import BlobCourier

func verifyBodyIsCorrect(data: Data, contentType: String, expectedParts: [String]) -> (Bool, String) {
  let body = String(data: data, encoding: .utf8) ?? ""

  let httpMessage = "Content-Type: \(contentType)\r\n\(body)"
  let bodyStartsWithBoundary = body.hasPrefix("--")
  if !bodyStartsWithBoundary {
    return (false, "Body must start with boundary")
  }

  do {
    let parsedMessage = try MimeParser().parse(httpMessage)
    if case .mixed(let mimes) = parsedMessage.content {
      let actualParts: [String] = mimes.reduce(into: []) { acc, mime in
        if let value = mime.header.contentDisposition?.parameters["name"] {
          acc.append(value)
        }
      }

      if actualParts.sorted() != expectedParts.sorted() {
        return (false, "Did not receive all expected parts")
      } else if actualParts != expectedParts {
        return (false, "Received parts order differs from provided order")
      }

      return (true, "Success")
    }
  } catch {
    return (false, error.localizedDescription)
  }

  return (false, "Unknown")
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class BlobCourierTests: XCTestCase {
    static let defaultPromiseTimeoutSeconds: Int = 10

    var sut: BlobCourier?

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = BlobCourier()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // swiftlint:disable function_body_length
    func testUploadMultipartMessageIsValid() throws {
        var result = (false, "Unknown")
        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        let expectedParts = ["test", "file"]

        let router = Router()
        router["/echo"] =
          DelayResponse(DataResponse(
            statusCode: 200,
            statusMessage: "OK",
            contentType: "text/plain",
            headers: []) { response -> Data in

            guard let input = response["swsgi.input"] as? SWSGIInput else { return Data("".utf8) }
            guard let contentType = response["CONTENT_TYPE"] as? String else { return Data("".utf8) }

            DataReader.read(input) { data in
              result = verifyBodyIsCorrect(
                data: data,
                contentType: contentType,
                expectedParts: expectedParts) }

            return Data("".utf8)
          })

        let httpServer = EmbeddedHttpServer(withRouter: router)

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
          result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }
        let resolveUpload: RCTPromiseResolveBlock = { (_: Any?) -> Void in print(""); dispatchGroup.leave() }
        let resolve: RCTPromiseResolveBlock = { (response: Any?) -> Void in
            let dict = response as? NSDictionary ?? [:]
            let data = dict["data"] as? NSDictionary ?? [:]

            try? httpServer.start()

            self.sut?.uploadBlob(input: [
             "parts": [
               [
                 "name": "test",
                 "payload": "SOME_TEST_STRING",
                 "type": "string"
               ],
               [
                 "name": "file",
                 "payload": [
                    "absoluteFilePath": data["absoluteFilePath"] ?? "",
                    "mimeType": "image/png"
                 ],
                 "type": "file"
               ]
             ],
             "taskId": data["taskId"] ?? "",
             "url": "http://localhost:12345/echo"
           ], resolve: resolveUpload, reject: reject)
        }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))

        httpServer.stop()

        XCTAssertTrue(result.0)
    }
    // swiftlint:enable function_body_length

    func testAllRequiredFetchParametersProvidedResolvesPromise() throws {
        var result = (false, "Unknown")
        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in result = (true, "Success"); dispatchGroup.leave() }
        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
          result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }

    func testMissingRequiredFetchParametersRejectsPromise() throws {
        let validInput = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        for removeKey in ["filename", "taskId", "url"] {
          var result = (false, "Unknown")

          let input = validInput.filter({ $0.key != removeKey })

          let dispatchGroup = DispatchGroup()

          dispatchGroup.enter()

          let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in
             result = (false, "Resolved, but expected reject"); dispatchGroup.leave() }
          let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, _: Error?) -> Void in
             result = (true, "Success"); dispatchGroup.leave() }

          sut?.fetchBlob(input: input as NSDictionary, resolve: resolve, reject: reject)

          dispatchGroup.wait(timeout: .now() +
            DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))

          XCTAssertTrue(result.0)
        }
    }

    func testAllRequiredUploadParametersProvidedResolvesPromise() throws {
        var result = (false, "Unknown")
        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
          result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }
        let resolveUpload: RCTPromiseResolveBlock = { (_: Any?) -> Void in
          result = (true, "Success"); dispatchGroup.leave() }
        let resolve: RCTPromiseResolveBlock = { (response: Any?) -> Void in
            let dict = response as? NSDictionary ?? [:]
            let data = dict["data"] as? NSDictionary ?? [:]

            self.sut?.uploadBlob(input: [
             "parts": [
               "file": [
                 "payload": [
                    "absoluteFilePath": data["absoluteFilePath"] ?? "",
                    "mimeType": "image/png"
                 ],
                 "type": "file"
               ]
             ],
             "taskId": data["taskId"] ?? "",
             "url": "https://file.io"
           ], resolve: resolveUpload, reject: reject)
        }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }

    func testMissingRequiredUploadParametersRejectsPromise() throws {
        var result = (false, "Unknown")
        let fetchInput: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        func createValidUploadInput(_ data: NSDictionary) -> [String: Any] {
          return [
            "taskId": data["taskId"] ?? "",
            "url": "https://file.io"
          ]
        }

        for removeKey in ["taskId", "url"] {
          let dispatchGroup = DispatchGroup()

          dispatchGroup.enter()

          let rejectFetch: RCTPromiseRejectBlock = { (_: String?, _: String?, _: Error?) -> Void in
            result = (false, "Rejected fetch request"); dispatchGroup.leave() }
          let rejectUpload: RCTPromiseRejectBlock = { (_: String?, _: String?, _: Error?) -> Void in
            result = (true, "Success"); dispatchGroup.leave() }
          let resolveUpload: RCTPromiseResolveBlock = { (_: Any?) -> Void in
            result = (false, "Resolved, but expected reject"); dispatchGroup.leave() }
          let resolve: RCTPromiseResolveBlock = { (response: Any?) -> Void in
              let dict = response as? NSDictionary ?? [:]
              let data = dict["data"] as? NSDictionary ?? [:]

              let validUploadInput = createValidUploadInput(data)

              let invalidUploadInput = validUploadInput.filter({ $0.key != removeKey })

              self.sut?.uploadBlob(
                input: invalidUploadInput as NSDictionary,
                resolve: resolveUpload,
                reject: rejectUpload)
          }

          sut?.fetchBlob(input: fetchInput, resolve: resolve, reject: rejectFetch)

          dispatchGroup.wait(timeout: .now() +
            DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
          XCTAssertTrue(result.0)
        }
    }

    func testValidTargetParametersResolvesPromise() throws {
        var result = (false, "Unknown")
        for target in ["cache", "data"] {
          let input: NSDictionary = [
            "filename": "some-filename.png",
            "ios": [
              "target": target
            ],
            "taskId": "some-task-id",
            "url": "https://github.com/edeckers/react-native-blob-courier"
          ]

          let dispatchGroup = DispatchGroup()

          dispatchGroup.enter()

          let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in
            result = (true, "Success"); dispatchGroup.leave() }
          let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
            result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }

          sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

          dispatchGroup.wait(timeout: .now() +
            DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
          XCTAssertTrue(result.0)
        }
    }

    func testInvalidTargetParametersRejectsPromise() throws {
        var result = (false, "Unknown")
        let target = "SOME_INVALID_VALUE"

        let input: NSDictionary = [
          "filename": "some-filename.png",
          "ios": [
            "target": target
          ],
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in
          result = (false, "Resolved, but expected reject"); dispatchGroup.leave() }
        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, _: Error?) -> Void in
          result = (true, "Success"); dispatchGroup.leave() }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }

    func testUnreachableFetchServerRejectsPromise() throws {
        var result = (false, "Unknown")

        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "http://127.0.0.1:12345"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in
          result = (false, "Resolved, but expected reject"); dispatchGroup.leave() }
        let reject: RCTPromiseRejectBlock = { (_, _, _) -> Void in
          result = (true, "Success"); dispatchGroup.leave() }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))

        XCTAssertTrue(result.0)
    }

    func testUploadOfNonExistentFileRejectsPromise() throws {
        var result = (false, "Unknown")

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in
          result = (false, "Resolved, but expected reject"); dispatchGroup.leave() }
        let reject: RCTPromiseRejectBlock = { (_, _, _) -> Void in
          result = (true, "Success"); dispatchGroup.leave() }

        self.sut?.uploadBlob(input: [
         "parts": [
           [
             "name": "file",
             "payload": [
                "absoluteFilePath": "/this/path/does/not/exist.png",
                "mimeType": "image/png"
             ],
             "type": "file"
           ]
         ],
         "taskId": "SOME_TASK_ID",
         "url": "https://file.io"
        ], resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }

    func testNonExistingFetchUrlResolvesPromise() throws {
        var result = (false, "Unknown")

        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/this-does-not-exist"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let resolve: RCTPromiseResolveBlock = { (_: Any?) -> Void in result = (true, "Success"); dispatchGroup.leave() }
        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
          result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }

    func testNonExistingUploadUrlResolvesPromise() throws {
        var result = (false, "Unknown")

        let input: NSDictionary = [
          "filename": "some-filename.png",
          "taskId": "some-task-id",
          "url": "https://github.com/edeckers/react-native-blob-courier"
        ]

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let reject: RCTPromiseRejectBlock = { (_: String?, _: String?, error: Error?) -> Void in
          result = (false, error?.localizedDescription ?? ""); dispatchGroup.leave() }
        let resolveUpload: RCTPromiseResolveBlock = { (_: Any?) -> Void in
          result = (true, "Success"); dispatchGroup.leave() }
        let resolve: RCTPromiseResolveBlock = { (response: Any?) -> Void in
            let dict = response as? NSDictionary ?? [:]
            let data = dict["data"] as? NSDictionary ?? [:]

            self.sut?.uploadBlob(input: [
             "parts": [
               "file": [
                 "payload": [
                    "absoluteFilePath": data["absoluteFilePath"] ?? "",
                    "mimeType": "image/png"
                 ],
                 "type": "file"
               ]
             ],
             "taskId": data["taskId"] ?? "",
             "url": "https://github.com/edeckers/this-does-not-exist"
           ], resolve: resolveUpload, reject: reject)
        }

        sut?.fetchBlob(input: input, resolve: resolve, reject: reject)

        dispatchGroup.wait(timeout: .now() +
          DispatchTimeInterval.seconds(BlobCourierTests.defaultPromiseTimeoutSeconds))
        XCTAssertTrue(result.0)
    }
}
