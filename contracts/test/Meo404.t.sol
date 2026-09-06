// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Meo404} from "../src/Meo404.sol";

contract Meo404Test is Test {
    Meo404 internal token;
    address internal owner = address(0xA11CE);
    address internal minter = address(0xB0B);
    address internal alice = address(0xA11);
    address internal bob = address(0xB0);

    bytes32 internal constant ENTITLEMENT = keccak256("roblox-purchase-abc");

    function setUp() public {
        token = new Meo404("Meo Meo Meo 404", "MEO404", owner);
        vm.prank(owner);
        token.setMinter(minter, true);
    }

    function test_mintRestrictedToMinter() public {
        vm.prank(alice);
        vm.expectRevert(Meo404.NotMinter.selector);
        token.mintFromEntitlement(alice, ENTITLEMENT);
    }

    function test_mintGivesTokenAndNft() public {
        vm.prank(minter);
        uint256 id = token.mintFromEntitlement(alice, ENTITLEMENT);

        assertEq(token.balanceOf(alice), token.UNITS_PER_NFT());
        assertEq(token.nftBalanceOf(alice), 1);
        assertEq(token.ownerOf(id), alice);
        assertEq(token.totalSupply(), token.UNITS_PER_NFT());
        assertTrue(token.entitlementUsed(ENTITLEMENT));
    }

    function test_mintIdempotent() public {
        vm.prank(minter);
        token.mintFromEntitlement(alice, ENTITLEMENT);

        vm.prank(minter);
        vm.expectRevert(Meo404.EntitlementAlreadyUsed.selector);
        token.mintFromEntitlement(alice, ENTITLEMENT);
    }

    function test_transferWholeTokenMovesNft() public {
        vm.prank(minter);
        token.mintFromEntitlement(alice, ENTITLEMENT);

		uint256 whole = token.UNITS_PER_NFT();
		vm.prank(alice);
		token.transfer(bob, whole);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.nftBalanceOf(alice), 0);
        assertEq(token.balanceOf(bob), token.UNITS_PER_NFT());
        assertEq(token.nftBalanceOf(bob), 1);
    }

    function test_fractionalTransferBurnsNft() public {
        vm.prank(minter);
        token.mintFromEntitlement(alice, ENTITLEMENT);

        vm.prank(alice);
        token.transfer(bob, 0.4e18);

        assertEq(token.nftBalanceOf(alice), 0);
        assertEq(token.nftBalanceOf(bob), 0);
        assertEq(token.balanceOf(alice), 0.6e18);
    }

    function test_fractionalCombineMintsNft() public {
        vm.prank(minter);
        token.mintFromEntitlement(alice, ENTITLEMENT);
        vm.prank(minter);
        token.mintFromEntitlement(bob, keccak256("other"));

        vm.prank(alice);
        token.transfer(address(0xC0), 0.6e18);
        vm.prank(bob);
        token.transfer(address(0xC0), 0.4e18);

        assertEq(token.balanceOf(address(0xC0)), 1e18);
        assertEq(token.nftBalanceOf(address(0xC0)), 1);
    }

    function test_nftTransferMovesUnits() public {
        vm.prank(minter);
        uint256 id = token.mintFromEntitlement(alice, ENTITLEMENT);

        vm.prank(alice);
        token.transferFromNFT(alice, bob, id);

        assertEq(token.ownerOf(id), bob);
        assertEq(token.balanceOf(bob), 1e18);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.nftBalanceOf(alice), 0);
    }

    function test_ownerCanRevokeMinter() public {
        vm.prank(owner);
        token.setMinter(minter, false);

        vm.prank(minter);
        vm.expectRevert(Meo404.NotMinter.selector);
        token.mintFromEntitlement(alice, ENTITLEMENT);
    }
}
