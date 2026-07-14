import React, { useState, createContext, useContext } from 'react';

interface DragHoverContextProps {
  hoveredSlot: number | null;
  hoveredInventory: string | null;
  setHoveredSlot: (slot: number | null, inventoryId: string | null) => void;
}

const DragHoverContext = createContext<DragHoverContextProps>({
  hoveredSlot: null,
  hoveredInventory: null,
  setHoveredSlot: () => {},
});

export const useDragHover = () => useContext(DragHoverContext);
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory, selectRightInventory } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch = useAppDispatch();
  const rightInventory = useAppSelector(selectRightInventory);

  const [hoveredSlot, setHoveredSlotState] = useState<number | null>(null);
  const [hoveredInventory, setHoveredInventoryState] = useState<string | null>(null);

  const setHoveredSlot = (slot: number | null, inventoryId: string | null) => {
    setHoveredSlotState(slot);
    setHoveredInventoryState(inventoryId);
  };

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible, inventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  const isSingle = !rightInventory || rightInventory.id === '' || rightInventory.slots === 0 || rightInventory.type === 'newdrop';

  return (
    <DragHoverContext.Provider value={{ hoveredSlot, hoveredInventory, setHoveredSlot }}>
      <Fade in={inventoryVisible}>
        <div className={`inventory-wrapper ${isSingle ? 'single-layout' : 'dual-layout'}`}>
          <LeftInventory />
          {!isSingle && <RightInventory />}
          <Tooltip />
          <InventoryContext />
        </div>
      </Fade>
      <InventoryHotbar />
    </DragHoverContext.Provider>
  );
};

export default Inventory;
