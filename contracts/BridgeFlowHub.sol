// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface of the BridgeFlowHub implementation.
/// @dev Adjust constructor signature to match your BridgeFlowHub.sol.
interface IBridgeFlowHub {
    // example: constructor(address _admin, address _bridge, address _feeCollector);
}

contract BridgeFlowHubDeployer {
    event BridgeFlowHubDeployed(address indexed hub, address indexed deployer);

    /// @notice Deploy a new BridgeFlowHub instance.
    /// @dev Replace parameters and the `new BridgeFlowHub(...)` call
    ///      so they match your real constructor.
    function deployBridgeFlowHub(
        address admin,
        address bridge,
        address feeCollector
    ) external returns (address) {
        require(admin != address(0), "Invalid admin");
        require(bridge != address(0), "Invalid bridge");
        require(feeCollector != address(0), "Invalid feeCollector");

        BridgeFlowHub hub = new BridgeFlowHub(admin, bridge, feeCollector);

        emit BridgeFlowHubDeployed(address(hub), msg.sender);
        return address(hub);
    }
}

/// @dev Stub for the real BridgeFlowHub contract.
/// In your project, delete this and instead:
/// `import "./BridgeFlowHub.sol";`
contract BridgeFlowHub {
    address public admin;
    address public bridge;
    address public feeCollector;

    constructor(address _admin, address _bridge, address _feeCollector) {
        admin = _admin;
        bridge = _bridge;
        feeCollector = _feeCollector;
    }
}
