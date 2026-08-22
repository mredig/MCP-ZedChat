struct GenericKeys: CodingKey, Hashable {
	var stringValue: String

	init(stringValue: String) {
		self.stringValue = stringValue
		self.intValue = Int(stringValue)
	}

	var intValue: Int?

	init(intValue: Int) {
		self.intValue = intValue
		self.stringValue = "\(intValue)"
	}
}
