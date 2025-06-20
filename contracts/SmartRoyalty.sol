// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    struct RoyaltyRecipient {
        address recipient;
        uint256 share; // in basis points (10000 = 100%)
    }

    mapping(uint256 => RoyaltyRecipient[]) public contentRoyalties;
    uint256 public contentCount;

    event RoyaltyConfigured(uint256 indexed contentId);
    event RoyaltyPaid(uint256 indexed contentId, uint256 amount);

    function configureRoyalty(uint256 contentId, address[] memory recipients, uint256[] memory shares) public {
        require(recipients.length == shares.length, "Mismatched inputs");

        uint256 totalShare = 0;
        delete contentRoyalties[contentId];

        for (uint256 i = 0; i < recipients.length; i++) {
            contentRoyalties[contentId].push(RoyaltyRecipient({
                recipient: recipients[i],
                share: shares[i]
            }));
            totalShare += shares[i];
        }

        require(totalShare == 10000, "Total shares must equal 10000");
        emit RoyaltyConfigured(contentId);
    }

    function payRoyalty(uint256 contentId) external payable {
        require(msg.value > 0, "Must send Ether");

        RoyaltyRecipient[] memory recipients = contentRoyalties[contentId];
        require(recipients.length > 0, "No royalty data found");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amount = (msg.value * recipients[i].share) / 10000;
            payable(recipients[i].recipient).transfer(amount);
        }

        emit RoyaltyPaid(contentId, msg.value);
    }
}
