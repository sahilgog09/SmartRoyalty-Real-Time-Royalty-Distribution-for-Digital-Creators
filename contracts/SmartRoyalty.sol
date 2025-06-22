// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    /// @notice Stores royalty recipient and their share in basis points (10000 = 100%)
    struct RoyaltyRecipient {
        address recipient;
        uint256 share; 
    }

    /// @dev Maps content ID to its list of royalty recipients
    mapping(uint256 => RoyaltyRecipient[]) public contentRoyalties;

    /// @notice Emitted when royalties are configured for a content ID
    event RoyaltyConfigured(uint256 indexed contentId);

    /// @notice Emitted when royalty is paid for a content ID
    event RoyaltyPaid(uint256 indexed contentId, uint256 amount);

    /**
     * @notice Set royalty recipients and their shares for a specific content ID
     * @param contentId Unique ID of the content
     * @param recipients Array of recipient addresses
     * @param shares Array of recipient shares (in basis points)
     */
    function configureRoyalty(
        uint256 contentId, 
        address[] calldata recipients, 
        uint256[] calldata shares
    ) external {
        uint256 len = recipients.length;
        require(len == shares.length, "Input lengths mismatch");

        uint256 totalShare = 0;
        delete contentRoyalties[contentId]; // Clear old data if any

        for (uint256 i = 0; i < len; ) {
            require(recipients[i] != address(0), "Zero address not allowed");

            contentRoyalties[contentId].push(RoyaltyRecipient({
                recipient: recipients[i],
                share: shares[i]
            }));

            totalShare += shares[i];
            unchecked { ++i; } // Safe because `i < len`
        }

        require(totalShare == 10000, "Shares must total 10000");
        emit RoyaltyConfigured(contentId);
    }

    /**
     * @notice Pay royalties for a specific content ID
     * @param contentId ID of the content to pay royalties for
     */
    function payRoyalty(uint256 contentId) external payable {
        require(msg.value > 0, "No Ether sent");

        RoyaltyRecipient[] storage recipients = contentRoyalties[contentId];
        uint256 len = recipients.length;
        require(len > 0, "No recipients configured");

        for (uint256 i = 0; i < len; ) {
            uint256 payment = (msg.value * recipients[i].share) / 10000;
            payable(recipients[i].recipient).transfer(payment);
            unchecked { ++i; } // Safe because `i < len`
        }

        emit RoyaltyPaid(contentId, msg.value);
    }

    /**
     * @notice Returns royalty recipients and their shares for a given content ID
     * @param contentId ID of the content
     * @return recipients Array of recipient addresses
     * @return shares Array of recipient shares in basis points
     */
    function getRoyaltyRecipients(uint256 contentId) 
        external 
        view 
        returns (address[] memory recipients, uint256[] memory shares) 
    {
        RoyaltyRecipient[] storage royalties = contentRoyalties[contentId];
        uint256 len = royalties.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i = 0; i < len; ) {
            recipients[i] = royalties[i].recipient;
            shares[i] = royalties[i].share;
            unchecked { ++i; }
        }
    }
}
