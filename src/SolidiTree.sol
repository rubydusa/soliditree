// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

error InvalidParent();

// todo:
// * check if constant expressions are compiled or are they called in instructor

// note:
// mainly do not care about deployment costs
contract SolidiTree {
    struct Node {
        uint256 index;
        uint256[] data;
    }

    uint256 immutable private MAX_NODES;
    uint256 immutable private MAX_BITS;
    uint256 immutable private NODES_PER_SLOT;

    // the slots where each array starts
    uint256 constant private DATA_SLOT = uint256(keccak256(abi.encodePacked(uint256(0))));
    uint256 constant private CHILDREN_SLOT = uint256(keccak256(abi.encodePacked(uint256(1))));
    uint256 constant private PARENTS_SLOT = uint256(keccak256(abi.encodePacked(uint256(2))));

    // data, children and parents are all right alligned

    // for each node, a buffer representing its data
    uint256[][] private _data;  // slot 0

    // for each node, a bit array such that the i-th bit represents whether i is a child of node
    uint256[][] private _children;  // slot 1

    // a tightly packed array of values each value using MAX_BITS.
    // if MAX_BITS does not divide 256, skip the remaining bits (ex: 7 fits 36 in 256, remained 4, don't use remaining 4 bits)
    uint256[] private _parents;  // slot 2

    uint256 private _currentNodes;

    constructor (uint256 maxNodes) {
        MAX_NODES = maxNodes;

        uint256 maxBits = 1;
        while (maxNodes > 1) {
            maxNodes /= 2;
            maxBits++;
        }

        MAX_BITS = maxBits;
        NODES_PER_SLOT = 256 / maxBits;
    }

    function _insertNode(uint256 parent, uint256[] memory data) internal {
        uint256 currentNodes = _currentNodes;
        if (parent >= currentNodes)
            revert InvalidParent();

        /*
         * Update Data
         */
        _data[currentNodes] = data;
        
        /*
         * Update Parents
         */
        uint256 nodesInLast = currentNodes % NODES_PER_SLOT;
        if (nodesInLast == 0) {
            // TODO: if computing parents length using currentNodes, use inline assembly instead of push
            _parents.push(parent);
        } else {
            // TODO: compute parents length using currentNodes
            uint256 last = _parents[_parents.length - 1];
            uint256 offset = nodesInLast * MAX_BITS;

            uint256 updatedLast = last | (parent << offset);
            _parents[_parents.length - 1] = updatedLast;
        }

        /*
         * Update Children
         *
         * Use inline assembly in order to enable skipping large portions of the array
         * Example:
         * 
         * currentNodes = 4000
         * parent = 96
         * parent has no other children
         * wihtout assembly you need to insert 238 slots to the array before you can update the relavent part
         */ 

        // inline assembly does not allow constant experssions in inline assembly for some reason
        uint256 _CHILDREN_SLOT = CHILDREN_SLOT;
        assembly {
            // the parent's children slot
            let parent_childs_s := add(_CHILDREN_SLOT, parent)
            // inside the parents children array, what is the index that needs to be written to
            let child_i := div(currentNodes, 0x100)
            
            // load the parent's children slot into memory
            let free := mload(0x40)
            mstore(free, parent_childs_s)
            mstore(0x40, add(free, 0x20))

            // the slot inside the parents's children array
            let child_slot_s := add(keccak256(free, 0x20), child_i)

            // the value of the slot
            let child_slot_v := sload(child_slot_s)

            // bit offset
            let offset := mod(currentNodes, 0x100)
            
            // updated child slot value
            let child_slot_u := or(child_slot_v, shl(offset, 1))

            // update the child slot
            sstore(child_slot_s, child_slot_u)
            
            // always update length:
            // this is more efficent because checking whether or not length needs to be updated requires an additonal sload
            sstore(parent_childs_s, add(child_i, 1))
        }
    }
}
