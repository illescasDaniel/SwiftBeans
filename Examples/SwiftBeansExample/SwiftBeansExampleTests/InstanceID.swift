import HTTIES

/// Identity of a handler bean. Free function: casting the existential inline inside a
/// test method crashed the Swift 6 compiler (SILGen).
func instanceID(of handler: any HTTPDataRequestHandler) -> ObjectIdentifier {
	ObjectIdentifier(handler as AnyObject)
}
