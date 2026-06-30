import DingDongMCPCore
import Foundation

let server = DingDongMCPServer(client: HTTPDingDongAPIClient())

while let line = readLine(strippingNewline: true) {
    guard let response = server.handleLine(line) else {
        continue
    }

    print(response)
    fflush(stdout)
}
