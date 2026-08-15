extension String {
    /// Texto de um buffer C preenchido pelo sistema, até o primeiro `\0`.
    init(nullTerminated buffer: [CChar]) {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        self.init(decoding: bytes, as: UTF8.self)
    }
}
