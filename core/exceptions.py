class PrismError(Exception):
    """Base exception for the Prism System."""
    pass

class ConfigurationError(PrismError):
    """Raised when configuration fails to load or is invalid."""
    pass

class SecurityError(PrismError):
    """Raised when security (biometric/crypto) checks fail."""
    pass

class InfrastructureError(PrismError):
    """Raised when blockchain, IPFS, or hardware fails."""
    pass
