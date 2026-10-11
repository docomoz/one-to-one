import Foundation

/// Сверка кода по QR, когда телефоны рядом (`VerifyQR`).
extension PairingFlow {
    /// Что показать в QR на телефоне без ключа: есть, когда на экране код сверки.
    var verifyQRPayload: String? {
        guard case .verify(let code) = joinStep, let joinRequestID else { return nil }
        return VerifyQR.payload(requestID: joinRequestID, code: code)
    }

    /// Телефон с ключом отсканировал QR. Тот же код — как «Совпадает», другой код — как «Не совпадает».
    /// QR не от этого запроса (старый, чужой, не наш) ничего не меняет.
    func confirmIncoming(scanned text: String) async {
        guard let scanned = VerifyQR.parse(text), scanned.requestID == incomingRequestID,
              case .verify(let code) = incomingStep
        else {
            errorMessage = VerifyQR.wrongQRMessage
            return
        }
        if scanned.code == code {
            await confirmIncoming()
        } else {
            await rejectIncoming()
        }
    }
}
