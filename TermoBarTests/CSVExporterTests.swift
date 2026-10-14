import Foundation
import Testing

struct CSVExporterTests {
    @Test func writesOneLinePerAppAndAnEmptyLineWithoutPower() {
        let samples = [
            makeSample(
                at: 0, duration: 5, temperature: 50.5, maxTemperature: 60, frontmostApp: "b",
                appPower: ["a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 2, gpu: 0.5)], pressure: 1, gpuPower: 0.5,
                fanSpeed: 2498.6),
            makeSample(at: 5, duration: 5, temperature: 51, pressure: nil),
        ]

        let csv = CSVExporter.csv(samples: samples, names: ["b": "Navegador"], timeZone: .gmt)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 5)
        #expect(
            lines[0]
                == "timestamp,duracao_s,temp_media_c,temp_max_c,pressao_termica,gpu_total_w,app_id,app,cpu_w,gpu_w,primeiro_plano,ventoinha_rpm"
        )
        #expect(lines[1] == "2001-01-01T00:00:00Z,5.000,50.500,60.000,1,0.500,b,Navegador,2.000,0.500,1,2499")
        #expect(lines[2] == "2001-01-01T00:00:00Z,5.000,50.500,60.000,1,0.500,a,a,1.000,0.000,0,2499")
        #expect(lines[3] == "2001-01-01T00:00:05Z,5.000,51.000,51.000,,,,,,,,")
        #expect(lines[4].isEmpty)
        #expect(lines.dropLast().allSatisfy { $0.split(separator: ",", omittingEmptySubsequences: false).count == 12 })
    }

    @Test func escapesSeparatorsAndQuotes() {
        #expect(CSVExporter.text("simples") == "simples")
        #expect(CSVExporter.text("a,b") == "\"a,b\"")
        #expect(CSVExporter.text("diz \"oi\"") == "\"diz \"\"oi\"\"\"")
        #expect(CSVExporter.text("linha\nnova") == "\"linha\nnova\"")
    }

    @Test(arguments: ["=HYPERLINK(\"x\")", "+1", "-cmd", "@SUM(A1)", "\tTAB"])
    func neutralizesFormulas(name: String) {
        let field = CSVExporter.text(name)
        #expect(field.hasPrefix("'") || field.hasPrefix("\"'"))
    }
}
