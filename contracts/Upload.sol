// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Upload {

    uint256 private totalOperations;
    uint256 private startTime;
    uint256 private timeWindow = 1 hours;

    struct Access {
        address user;
        bool access; // true or false
    }

    event DataIntegrityVerified(address indexed user, bytes32 calculatedRoot, bytes32 storedRoot);
    event TMerkleTreeHeightCalculated(address indexed user, uint256 height);
    event DebugLog(string message, uint256 value);

    struct TMerkleTreeNode {
        bytes32 hash;
        mapping(uint256 => TMerkleTreeNode) children;
    }

    constructor() {
        startTime = block.timestamp;
    }

    mapping(address => string[]) value;
    mapping(address => mapping(address => bool)) ownership;
    mapping(address => Access[]) accessList;
    mapping(address => mapping(address => bool)) previousData;
    mapping(address => bytes32) tMerkleRoots;

    uint256 constant MAX_CHILDREN = 4; // Maximum children per node
    uint256 constant MAX_HEIGHT = 256; // Maximum tree height

    // INCREMENT TOTAL OPERATIONS COUNT
    function incrementTotalOperations() internal {
        totalOperations++;
    }

    // CALCULATE THROUGHPUT
    function calculateThroughput() internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - startTime;
        return (totalOperations * 1 ether) / elapsedTime; // Throughput in operations per second (OPS)
    }

    // ADD DATA TO T-MERKLE TREE
    function addToTMerkleTree(address _user, string memory url) internal {
        value[_user].push(url);
        // Recalculate T-Merkle root when new data is added
        tMerkleRoots[_user] = calculateTMerkleRoot(_user);
    }

    // T-MERKLE ROOT OF USER'S DATA
    function calculateTMerkleRoot(address _user) internal view returns (bytes32) {
        string[] memory data = value[_user];
        bytes32[] memory leaves = new bytes32[](data.length);

        for (uint i = 0; i < data.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(data[i]));
        }

        return createTMerkleTree(leaves);
    }

    // CREATE T-MERKLE TREE FROM LEAF NODES
    function createTMerkleTree(bytes32[] memory leaves) internal pure returns (bytes32) {
        uint n = leaves.length;
        if (n == 0) {
            return 0x0;
        }

        while (n > 1) {
            uint256 newN = (n + MAX_CHILDREN - 1) / MAX_CHILDREN; // Round up division
            bytes32[] memory newLeaves = new bytes32[](newN);

            for (uint i = 0; i < n; i += MAX_CHILDREN) {
                uint256 endIndex = i + MAX_CHILDREN < n ? i + MAX_CHILDREN : n;
                bytes32[MAX_CHILDREN] memory childHashes;

                for (uint j = i; j < endIndex; j++) {
                    childHashes[j - i] = leaves[j];
                }

                bytes32 hash = computeParentHash(childHashes);
                newLeaves[i / MAX_CHILDREN] = hash;
            }

            n = newN;
            leaves = newLeaves;
        }

        return leaves[0];
    }

    // Compute parent hash from child hashes
    function computeParentHash(bytes32[MAX_CHILDREN] memory childHashes) internal pure returns (bytes32) {
        bytes memory combinedHashes = abi.encodePacked(childHashes);
        return keccak256(combinedHashes);
    }

    // T-MERKLE TREE HEIGHT
    function calculateTMerkleTreeHeight(address _user) external returns (uint256) {
    uint256 height = 0;
    uint256 leafCount = value[_user].length;

    // Debugging: Log initial leaf count
    emit DebugLog("Initial leaf count", leafCount);

    while (leafCount > 1) {
        leafCount = (leafCount + MAX_CHILDREN - 1) / MAX_CHILDREN; // Round up division
        height++;

        // Debugging: Log updated leaf count and height
        emit DebugLog("Updated leaf count", leafCount);
        emit DebugLog("Height", height);
    }

    return height;
}

    // ADD DATA AND UPDATE T-MERKLE TREE
    function add(address _user, string memory url) external {
        addToTMerkleTree(_user, url);
        incrementTotalOperations();
    }

    // ALLOW OWNERSHIP
    function allow(address user) external {//def
        ownership[msg.sender][user] = true; 
        if (previousData[msg.sender][user]) {
            for (uint i = 0; i < accessList[msg.sender].length; i++) {
                if (accessList[msg.sender][i].user == user) {
                    accessList[msg.sender][i].access = true; 
                }
            }
        } else {
            accessList[msg.sender].push(Access(user, true));  
            previousData[msg.sender][user] = true;  
        }
    }

    // DISALLOW OWNERSHIP
    function disallow(address user) public {
        ownership[msg.sender][user] = false;
        for (uint i = 0; i < accessList[msg.sender].length; i++) {
            if (accessList[msg.sender][i].user == user) {
                accessList[msg.sender][i].access = false;  
            }
        }
    }

    function display(address _user) external view returns (string[] memory) {
        require(_user == msg.sender || ownership[_user][msg.sender], "You don't have access");
        return value[_user];
    }

    function shareAccess() public view returns (Access[] memory) {
        return accessList[msg.sender];
    }

    // VERIFY DATA INTEGRITY USING T-MERKLE TREE
    function verifyDataIntegrity(address _user) internal returns (bool) {
        bytes32 currentRoot = calculateTMerkleRoot(_user);
        emit DataIntegrityVerified(_user, currentRoot, tMerkleRoots[_user]);
        return currentRoot == tMerkleRoots[_user];
    }

    // CALCULATE GAS COST FOR VERIFYING DATA INTEGRITY
    function calculateGasCostForVerification(address _user) external returns (uint256) {
    uint256 gasStart = gasleft(); // Start gas measurement

    // Call verifyDataIntegrity function to measure gas cost
    verifyDataIntegrity(_user);

    uint256 gasEnd = gasleft(); // End gas measurement

    uint256 gasUsed = gasStart - gasEnd; // Calculate gas used
    return gasUsed;
}

}
