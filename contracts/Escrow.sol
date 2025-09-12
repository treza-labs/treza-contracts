// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BasicEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum EscrowState { 
        Created, 
        Funded, 
        Completed, 
        Disputed, 
        Refunded 
    }

    struct EscrowOrder {
        address buyer;
        address seller;
        address arbitrator;
        uint256 amount;
        address tokenAddress; // address(0) for ETH
        EscrowState state;
        uint256 createdAt;
        uint256 timeoutDuration;
        string description;
    }

    mapping(uint256 => EscrowOrder) public escrows;
    uint256 public nextEscrowId = 1;
    uint256 public arbitratorFeePercent = 250; // 2.5% in basis points
    
    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        address tokenAddress
    );
    
    event EscrowFunded(uint256 indexed escrowId);
    event EscrowCompleted(uint256 indexed escrowId);
    event EscrowDisputed(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);

    modifier onlyBuyer(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].buyer, "Only buyer can call this");
        _;
    }

    modifier onlySeller(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].seller, "Only seller can call this");
        _;
    }

    modifier onlyArbitrator(uint256 escrowId) {
        require(msg.sender == escrows[escrowId].arbitrator, "Only arbitrator can call this");
        _;
    }

    modifier validEscrow(uint256 escrowId) {
        require(escrowId < nextEscrowId && escrowId > 0, "Invalid escrow ID");
        _;
    }

    /**
     * @dev Create a new escrow order
     * @param seller Address of the seller
     * @param arbitrator Address of the arbitrator (can be address(0) for no arbitrator)
     * @param amount Amount to be escrowed
     * @param tokenAddress Token contract address (address(0) for ETH)
     * @param timeoutDuration Duration in seconds after which buyer can request refund
     * @param description Description of the escrow order
     */
    function createEscrow(
        address seller,
        address arbitrator,
        uint256 amount,
        address tokenAddress,
        uint256 timeoutDuration,
        string memory description
    ) external returns (uint256) {
        require(seller != address(0), "Invalid seller address");
        require(amount > 0, "Amount must be greater than 0");
        require(timeoutDuration > 0, "Timeout duration must be greater than 0");

        uint256 escrowId = nextEscrowId++;
        
        escrows[escrowId] = EscrowOrder({
            buyer: msg.sender,
            seller: seller,
            arbitrator: arbitrator,
            amount: amount,
            tokenAddress: tokenAddress,
            state: EscrowState.Created,
            createdAt: block.timestamp,
            timeoutDuration: timeoutDuration,
            description: description
        });

        emit EscrowCreated(escrowId, msg.sender, seller, amount, tokenAddress);
        return escrowId;
    }

    /**
     * @dev Fund an escrow with ETH or ERC20 tokens
     */
    function fundEscrow(uint256 escrowId) 
        external 
        payable 
        validEscrow(escrowId) 
        onlyBuyer(escrowId) 
        nonReentrant 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Created, "Escrow already funded or completed");

        if (escrow.tokenAddress == address(0)) {
            // ETH escrow
            require(msg.value == escrow.amount, "Incorrect ETH amount");
        } else {
            // ERC20 escrow
            require(msg.value == 0, "Don't send ETH for token escrow");
            IERC20(escrow.tokenAddress).safeTransferFrom(
                msg.sender, 
                address(this), 
                escrow.amount
            );
        }

        escrow.state = EscrowState.Funded;
        emit EscrowFunded(escrowId);
    }

    /**
     * @dev Complete escrow and release funds to seller (buyer confirms receipt)
     */
    function completeEscrow(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
        onlyBuyer(escrowId) 
        nonReentrant 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Funded, "Escrow not funded");

        escrow.state = EscrowState.Completed;
        
        _releaseFundsToSeller(escrowId);
        emit EscrowCompleted(escrowId);
    }

    /**
     * @dev Request refund after timeout period
     */
    function requestRefund(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
        onlyBuyer(escrowId) 
        nonReentrant 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Funded, "Escrow not funded");
        require(
            block.timestamp >= escrow.createdAt + escrow.timeoutDuration, 
            "Timeout period not reached"
        );

        escrow.state = EscrowState.Refunded;
        
        _refundToBuyer(escrowId);
        emit EscrowRefunded(escrowId);
    }

    /**
     * @dev Initiate dispute (can be called by buyer or seller)
     */
    function initiateDispute(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Funded, "Escrow not funded");
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "Only buyer or seller can initiate dispute"
        );
        require(escrow.arbitrator != address(0), "No arbitrator set");

        escrow.state = EscrowState.Disputed;
        emit EscrowDisputed(escrowId);
    }

    /**
     * @dev Resolve dispute (arbitrator decides)
     * @param escrowId The escrow ID
     * @param releaseTo Address to release funds to (buyer for refund, seller for completion)
     */
    function resolveDispute(uint256 escrowId, address releaseTo) 
        external 
        validEscrow(escrowId) 
        onlyArbitrator(escrowId) 
        nonReentrant 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Disputed, "Escrow not in dispute");
        require(
            releaseTo == escrow.buyer || releaseTo == escrow.seller,
            "Invalid release address"
        );

        if (releaseTo == escrow.seller) {
            escrow.state = EscrowState.Completed;
            _releaseFundsToSeller(escrowId);
            emit EscrowCompleted(escrowId);
        } else {
            escrow.state = EscrowState.Refunded;
            _refundToBuyer(escrowId);
            emit EscrowRefunded(escrowId);
        }
    }

    /**
     * @dev Internal function to release funds to seller
     */
    function _releaseFundsToSeller(uint256 escrowId) private {
        EscrowOrder storage escrow = escrows[escrowId];
        
        uint256 arbitratorFee = 0;
        if (escrow.arbitrator != address(0) && escrow.state == EscrowState.Completed) {
            arbitratorFee = (escrow.amount * arbitratorFeePercent) / 10000;
        }
        
        uint256 sellerAmount = escrow.amount - arbitratorFee;

        if (escrow.tokenAddress == address(0)) {
            // ETH transfer
            (bool success,) = escrow.seller.call{value: sellerAmount}("");
            require(success, "ETH transfer to seller failed");
            
            if (arbitratorFee > 0) {
                (bool feeSuccess,) = escrow.arbitrator.call{value: arbitratorFee}("");
                require(feeSuccess, "ETH transfer to arbitrator failed");
            }
        } else {
            // ERC20 transfer
            IERC20(escrow.tokenAddress).safeTransfer(escrow.seller, sellerAmount);
            
            if (arbitratorFee > 0) {
                IERC20(escrow.tokenAddress).safeTransfer(escrow.arbitrator, arbitratorFee);
            }
        }
    }

    /**
     * @dev Internal function to refund to buyer
     */
    function _refundToBuyer(uint256 escrowId) private {
        EscrowOrder storage escrow = escrows[escrowId];

        if (escrow.tokenAddress == address(0)) {
            // ETH refund
            (bool success,) = escrow.buyer.call{value: escrow.amount}("");
            require(success, "ETH refund failed");
        } else {
            // ERC20 refund
            IERC20(escrow.tokenAddress).safeTransfer(escrow.buyer, escrow.amount);
        }
    }

    /**
     * @dev Get escrow details
     */
    function getEscrow(uint256 escrowId) 
        external 
        view 
        validEscrow(escrowId) 
        returns (EscrowOrder memory) 
    {
        return escrows[escrowId];
    }

    /**
     * @dev Check if escrow has timed out
     */
    function isTimedOut(uint256 escrowId) 
        external 
        view 
        validEscrow(escrowId) 
        returns (bool) 
    {
        EscrowOrder storage escrow = escrows[escrowId];
        return block.timestamp >= escrow.createdAt + escrow.timeoutDuration;
    }

    // Utility functions for string formatting
    function _uint2str(uint256 _i) private pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    function _addressToString(address _addr) private pure returns (string memory) {
        bytes32 _bytes = bytes32(uint256(uint160(_addr)));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _string = new bytes(42);
        _string[0] = '0';
        _string[1] = 'x';
        for(uint i = 0; i < 20; i++) {
            _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }
        return string(_string);
    }
}