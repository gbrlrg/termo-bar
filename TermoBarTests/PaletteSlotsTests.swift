import Testing

struct PaletteSlotsTests {
    @Test func assignsFirstFreeSlotsToTopApps() {
        var slots = PaletteSlots(capacity: 2)
        slots.update(ranking: ["a", "b", "c"])
        #expect(slots["a"] == 0)
        #expect(slots["b"] == 1)
        #expect(slots["c"] == nil)
        #expect(slots.apps == ["a", "b"])
    }

    @Test func keepsColorsStableWhileAppsStayOnTop() {
        var slots = PaletteSlots(capacity: 3)
        slots.update(ranking: ["a", "b", "c"])
        slots.update(ranking: ["c", "d", "a"])
        #expect(slots["a"] == 0)
        #expect(slots["c"] == 2)
        #expect(slots["d"] == 1)
        #expect(slots["b"] == nil)
    }
}
