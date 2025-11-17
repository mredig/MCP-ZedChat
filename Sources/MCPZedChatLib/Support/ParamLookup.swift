import MCP
import Foundation

@dynamicMemberLookup
struct ParamLookup<T> {
	let paramsIn: CallTool.Parameters

	let keyPath: KeyPath<Value, Optional<T>>

	subscript<S: ExpressibleByStringLiteral>(dynamicMember dynamicMember: S) -> T? {
		guard let baseValue = paramsIn.arguments?["\(dynamicMember)"] else { return nil }
		return baseValue[keyPath: keyPath]
	}
}

extension CallTool.Parameters {
	var integers: ParamLookup<Int> {
		ParamLookup(paramsIn: self, keyPath: \.intValue)
	}

	var strings: ParamLookup<String> {
		ParamLookup(paramsIn: self, keyPath: \.stringValue)
	}

	var doubles: ParamLookup<Double> {
		ParamLookup(paramsIn: self, keyPath: \.doubleValue)
	}

	var bools: ParamLookup<Bool> {
		ParamLookup(paramsIn: self, keyPath: \.boolValue)
	}

	var data: ParamLookup<(mimeType: String?, Data)> {
		ParamLookup(paramsIn: self, keyPath: \.dataValue)
	}
}
