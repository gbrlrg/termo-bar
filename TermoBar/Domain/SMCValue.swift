/// Decodificação dos valores do controlador do sistema (SMC).
///
/// Fica fora do `FanReader`, que conversa com o AppleSMC, para poder ser testada.
enum SMCValue {
    /// Código de quatro letras de uma chave ou de um tipo ("F0Ac", "flt ") como o SMC o usa.
    static func fourCC(_ name: String) -> UInt32 {
        name.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    }

    /// No Apple Silicon a rotação vem como `flt ` (float little-endian); os inteiros são big-endian.
    static func decode(_ bytes: [UInt8], type: UInt32) -> Double? {
        let bigEndian = bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        switch (type, bytes.count) {
        case (fourCC("flt "), 4): return Double(Float(bitPattern: bigEndian.byteSwapped))
        case (fourCC("ui8 "), 1), (fourCC("ui16"), 2), (fourCC("ui32"), 4): return Double(bigEndian)
        case (fourCC("fpe2"), 2): return Double(bigEndian) / 4
        default: return nil
        }
    }
}
