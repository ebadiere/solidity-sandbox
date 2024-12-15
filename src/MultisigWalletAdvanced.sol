// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MultisigWalletAdvanced{

    address[] public owners;
    uint256 public quorum;

    error quorumCannotExceedOwners();
    error signatureQuorumNotMet();
    error invalidSignature();
    error duplicateSignature();
    error notAnOwner();
    error transferFailed();

    constructor(address[] memory _owners, uint256 _quorum) {
        if (_quorum > _owners.length) {
            revert quorumCannotExceedOwners();
        }
        owners = _owners;
        quorum = _quorum;
    }

    function isOwner(address _address) public view returns (bool) {
        for(uint256 i = 0; i < owners.length; i++) {
            if(owners[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function triggerTransaction(address _recipient, uint256 _amount, bytes[] memory signatures) external {
        if (signatures.length < quorum) {
            revert signatureQuorumNotMet();
        }

        // Create transaction message hash
        bytes32 txHash = keccak256(abi.encodePacked(_recipient, _amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        
        // Track used addresses to prevent duplicate signatures
        address[] memory usedAddresses = new address[](signatures.length);
        uint256 validSignatures;

        // Verify each signature
        for(uint256 i = 0; i < signatures.length; i++) {
            // Recover signer address from signature
            address recoveredSigner = recoverSigner(ethSignedHash, signatures[i]);
            
            // Check if signer is an owner
            if(!isOwner(recoveredSigner)) {
                revert notAnOwner();
            }

            // Check for duplicate signatures
            for(uint256 j = 0; j < validSignatures; j++) {
                if(usedAddresses[j] == recoveredSigner) {
                    revert duplicateSignature();
                }
            }

            usedAddresses[validSignatures] = recoveredSigner;
            validSignatures++;
        }

        // If we get here, all signatures are valid and from unique owners
        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) {
            revert transferFailed();
        }
    }

    function recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address) {
        if(_signature.length != 65) {
            revert invalidSignature();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            revert invalidSignature();
        }

        address recoveredAddress = ecrecover(_hash, v, r, s);
        if (recoveredAddress == address(0)) {
            revert invalidSignature();
        }

        return recoveredAddress;
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}