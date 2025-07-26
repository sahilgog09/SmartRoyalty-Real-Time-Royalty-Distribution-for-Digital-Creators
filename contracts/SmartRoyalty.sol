// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SmartRoyalty is Ownable {
    uint256 public constant BASIS_POINTS = 10_000;

    struct Royalty {
        address recipient;
        uint96 share; // Gas-efficient: fits more into one storage slot
    }

    mapping(uint256 => Royalty[]) private _royaltyInfo;

    event RoyaltiesConfigured(uint256 indexed contentId);
    event RoyaltyPaid(uint256 indexed contentId, uint256 amount);
    event RecipientChanged(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validateInput(address[] calldata recipients, uint256[] calldata shares) {
        require(recipients.length > 0, "No recipients");
        require(recipients.length == shares.length, "Length mismatch");
        _;
    }



    /**
     * @dev Set royalty recipients and their shares for a given content ID.
     * Only the contract owner can perform this action.
     */
    function configureRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external onlyOwner validateInput(recipients, shares) {
        delete _royaltyInfo[contentId];
        Royalty[] storage list = _royaltyInfo[contentId];

        uint256 totalShare;
        for (uint256 i; i < recipients.length; ) {
            address recipient = recipients[i];
            uint256 share = shares[i];

            require(recipient != address(0), "Invalid recipient");
            require(share > 0 && share <= BASIS_POINTS, "Invalid share");

            list.push(Royalty(recipient, uint96(share)));
            totalShare += share;

            unchecked { ++i; }
        }

        require(totalShare == BASIS_POINTS, "Total share ≠ 10000");
        emit RoyaltiesConfigured(contentId);
    }

    /**
     * @dev Pay royalties to recipients based on the amount of ETH sent.
     */
    function distributeRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "Zero value");

        Royalty[] storage list = _royaltyInfo[contentId];
        uint256 len = list.length;
        require(len > 0, "Royalties not set");

        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;

            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Transfer failed");

            unchecked { ++i; }
        }

        emit RoyaltyPaid(contentId, amount);
    }

    /**
     * @dev View royalty distribution for a specific content ID.
     */
    function viewRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        Royalty[] storage list = _royaltyInfo[contentId];
        uint256 len = list.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ) {
            recipients[i] = list[i].recipient;
            shares[i] = list[i].share;
            unchecked { ++i; }
        }
    }

    /**
     * @dev Update an existing recipient to a new address.
     * Can be called by the old recipient or the contract owner.
     */
    function changeRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "New recipient is zero");

        Royalty[] storage list = _royaltyInfo[contentId];
        uint256 len = list.length;

        for (uint256 i; i < len; ) {
            if (list[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient || msg.sender == owner(), "Unauthorized");
                list[i].recipient = newRecipient;

                emit RecipientChanged(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert("Old recipient not found");
    }

    /**
     * @dev Reject ETH sent without purpose.
     */
    receive() external payable {
        revert("Use distributeRoyalties()");
    }
}
