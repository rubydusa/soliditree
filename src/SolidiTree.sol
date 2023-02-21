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

        // update the data of the node
        _data[currentNodes] = data;
        
        /* 
        // solidity doesn't allow constant expressions in assembly for some reason
        uint256 _MAX_BITS = MAX_BITS;
        uint256 _NODES_PER_SLOT = NODES_PER_SLOT;
        uint256 _CHILDREN_SLOT = CHILDREN_SLOT;
        uint256 _PARENTS_SLOT = PARENTS_SLOT;

        // todo (backburner): check if parents update - branched version saves gas
        assembly {
            /s*
             *  Update Parents
             *s/

            let parents_length := sload(_parents.slot)  // TODO: compute using currentNodes
            // the last slot in the parents array
            let parents_last_s := add(_PARENTS_SLOT, parents_length)
            // the last slot value
            let parents_last := sload(parents_last_s)

            // how many nodes are in the last slot
            let nodes_in_last := mod(currentNodes, _NODES_PER_SLOT)

            // since length starts at zero, the first time insert is called
            // parents_last is _parents.slot, so consider a 0 amount of nodes in last to be full
            let is_full := iszero(nodes_in_last)

            // bit offset
            let offset := mul(nodes_in_last, _MAX_BITS)
            // updated parents slot
            let parents_last_u := or(mul(parents_last, not(is_full)), shl(offset, parent))

            // update parents' last slot
            sstore(add(parents_last_s, is_full), parents_last_u)

            // in case full, update array length
            if is_full {
                sstore(_parents.slot, add(parents_length, 1))
            }

            /s*
             * Update Children
             *s/
            
            // currentNodes (pre-update) is the index of the new node.
            // since children is a bit 
            let children_i := div(currentNodes, 256)
            let parent_child := add(_CHILDREN_SLOT, parent)
            
            // update the amount of current nodes
            sstore(_currentNodes.slot, add(currentNodes, 1))
        }
        */
    }
}
