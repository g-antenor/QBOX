import React, { useCallback, useRef } from 'react';
import { DragSource, Inventory, InventoryType, Slot, SlotWithItem } from '../../typings';
import { useDrag, useDragDropManager, useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { useDragHover } from './index';
import WeightBar from '../utils/WeightBar';
import { onDrop } from '../../dnd/onDrop';
import { onBuy } from '../../dnd/onBuy';
import { Items } from '../../store/items';
import { canCraftItem, canPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
import { onUse } from '../../dnd/onUse';
import { Locale } from '../../store/locale';
import { onCraft } from '../../dnd/onCraft';
import useNuiEvent from '../../hooks/useNuiEvent';
import { ItemsPayload } from '../../reducers/refreshSlots';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { useMergeRefs } from '@floating-ui/react';

interface SlotProps {
  inventoryId: Inventory['id'];
  inventoryType: Inventory['type'];
  inventoryGroups: Inventory['groups'];
  item: Slot;
}

interface FootprintResult {
  anchorSlot: number;
  width: number;
  height: number;
  slots: number[];
  isBlocked: boolean;
  freeCount: number;
}

const getBestFootprint = (
  inventoryItems: any[],
  totalSlots: number,
  hoveredSlot: number,
  w: number,
  h: number,
  sourceSlot?: number,
  sourceInventory?: string,
  targetInventory?: string
): FootprintResult => {
  if (w === 1 && h === 1) {
    const targetItem = inventoryItems[hoveredSlot - 1];
    const isOccupied = targetItem && targetItem.name && !(sourceSlot !== undefined && sourceInventory === targetInventory && targetItem.slot === sourceSlot);
    return {
      anchorSlot: hoveredSlot,
      width: 1,
      height: 1,
      slots: [hoveredSlot],
      isBlocked: false, // Always allow swap / stack
      freeCount: isOccupied ? 0 : 1,
    };
  }

  const totalRows = Math.ceil(totalSlots / 5);
  const col = (hoveredSlot - 1) % 5;
  const row = Math.floor((hoveredSlot - 1) / 5);

  const checkCandidate = (cw: number, ch: number): FootprintResult | null => {
    const anchorCol = Math.max(0, Math.min(col, 5 - cw));
    const anchorRow = Math.max(0, Math.min(row, totalRows - ch));
    const anchorSlot = (anchorRow * 5) + anchorCol + 1;

    if (anchorCol + cw > 5 || anchorRow + ch > totalRows) return null;

    const slots: number[] = [];
    let isBlocked = false;
    let freeCount = 0;

    for (let r = 0; r < ch; r++) {
      for (let c = 0; c < cw; c++) {
        const slotNum = anchorSlot + (r * 5) + c;
        if (slotNum > totalSlots) {
          isBlocked = true;
          continue;
        }
        slots.push(slotNum);

        const targetItem = inventoryItems[slotNum - 1];
        let isOccupied = false;
        if (targetItem && targetItem.name) {
          if (!(sourceSlot !== undefined && sourceInventory === targetInventory && targetItem.slot === sourceSlot)) {
            isOccupied = true;
          }
        }
        if (!isOccupied) {
          freeCount++;
        } else {
          isBlocked = true;
        }
      }
    }

    return { anchorSlot, width: cw, height: ch, slots, isBlocked, freeCount };
  };

  const cand1 = checkCandidate(w, h);
  const cand2 = checkCandidate(h, w);

  if (cand1 && !cand1.isBlocked) {
    return cand1;
  }
  if (cand2 && !cand2.isBlocked) {
    return cand2;
  }

  if (cand1 && cand2) {
    if (cand2.freeCount > cand1.freeCount) {
      return cand2;
    }
    return cand1;
  }

  return cand1 || cand2 || { anchorSlot: hoveredSlot, width: w, height: h, slots: [], isBlocked: true, freeCount: 0 };
};

const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups },
  ref
) => {
  const manager = useDragDropManager();
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);

  const leftInventory = useAppSelector((state) => state.inventory.leftInventory);
  const rightInventory = useAppSelector((state) => state.inventory.rightInventory);
  const inventory = inventoryId === leftInventory.id ? leftInventory : rightInventory;

  const { hoveredSlot, hoveredInventory, setHoveredSlot } = useDragHover();

  const canDrag = useCallback(() => {
    return canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) && canCraftItem(item, inventoryType);
  }, [item, inventoryType, inventoryGroups]);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () =>
        isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
            inventory: inventoryType,
            item: {
              name: item.name,
              slot: item.slot,
            },
            image: item?.name && `url(${getItemUrl(item) || 'none'}`,
          }
          : null,
      canDrag,
    }),
    [inventoryType, item]
  );

  const [{ isOver, canDrop, draggingItem }, drop] = useDrop<
    DragSource,
    void,
    { isOver: boolean; canDrop: boolean; draggingItem: DragSource | null }
  >(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        isOver: monitor.isOver({ shallow: true }),
        canDrop: monitor.canDrop(),
        draggingItem: monitor.getItem(),
      }),
      hover: (source, monitor) => {
        if (monitor.isOver({ shallow: true })) {
          const dragSize = (Items[source.item.name] as any)?.size;
          let w = 1, h = 1;
          if (dragSize) {
            if (typeof dragSize === 'object' && !Array.isArray(dragSize)) {
              w = dragSize.width || 1;
              h = dragSize.height || 1;
            } else if (Array.isArray(dragSize)) {
              w = dragSize[0] || 1;
              h = dragSize[1] || 1;
            }
          }
          const isRotated = (source as any)?.item?.metadata?.rotated;
          if (isRotated) {
            const temp = w;
            w = h;
            h = temp;
          }
          const res = getBestFootprint(inventory.items, inventory.slots, item.slot, w, h, source.item.slot, source.inventory, inventoryType);
          setHoveredSlot(res.anchorSlot, inventoryId);
        }
      },
      drop: (source) => {
        dispatch(closeTooltip());
        const dragSize = (Items[source.item.name] as any)?.size;
        let w = 1, h = 1;
        if (dragSize) {
          if (typeof dragSize === 'object' && !Array.isArray(dragSize)) {
            w = dragSize.width || 1;
            h = dragSize.height || 1;
          } else if (Array.isArray(dragSize)) {
            w = dragSize[0] || 1;
            h = dragSize[1] || 1;
          }
        }
        const isRotated = (source as any)?.item?.metadata?.rotated;
        if (isRotated) {
          const temp = w;
          w = h;
          h = temp;
        }
        const res = getBestFootprint(inventory.items, inventory.slots, item.slot, w, h, source.item.slot, source.inventory, inventoryType);

        switch (source.inventory) {
          case InventoryType.SHOP:
            onBuy(source, { inventory: inventoryType, item: { slot: res.anchorSlot } });
            break;
          case InventoryType.CRAFTING:
            onCraft(source, { inventory: inventoryType, item: { slot: res.anchorSlot } });
            break;
          default:
            onDrop(source, { inventory: inventoryType, item: { slot: res.anchorSlot } });
            break;
        }
      },
      canDrop: (source) => {
        if (inventoryType === InventoryType.SHOP || inventoryType === InventoryType.CRAFTING) return false;

        const dragSize = (Items[source.item.name] as any)?.size;
        let w = 1, h = 1;
        if (dragSize) {
          if (typeof dragSize === 'object' && !Array.isArray(dragSize)) {
            w = dragSize.width || 1;
            h = dragSize.height || 1;
          } else if (Array.isArray(dragSize)) {
            w = dragSize[0] || 1;
            h = dragSize[1] || 1;
          }
        }
        const isRotated = (source as any)?.item?.metadata?.rotated;
        if (isRotated) {
          const temp = w;
          w = h;
          h = temp;
        }

        const res = getBestFootprint(inventory.items, inventory.slots, item.slot, w, h, source.item.slot, source.inventory, inventoryType);
        if (source.item.slot === res.anchorSlot && source.inventory === inventoryType) return false;

        return !res.isBlocked;
      },
    }),
    [inventoryType, item, inventory, hoveredSlot, hoveredInventory]
  );

  const { inFootprint, isFootprintBlocked } = React.useMemo(() => {
    if (hoveredSlot === null || hoveredInventory !== inventoryId || !draggingItem) {
      return { inFootprint: false, isFootprintBlocked: false };
    }

    const dragSize = (Items[draggingItem.item.name] as any)?.size;
    let w = 1, h = 1;
    if (dragSize) {
      if (typeof dragSize === 'object' && !Array.isArray(dragSize)) {
        w = dragSize.width || 1;
        h = dragSize.height || 1;
      } else if (Array.isArray(dragSize)) {
        w = dragSize[0] || 1;
        h = dragSize[1] || 1;
      }
    }
    const isRotated = (draggingItem as any)?.item?.metadata?.rotated;
    if (isRotated) {
      const temp = w;
      w = h;
      h = temp;
    }

    const res = getBestFootprint(inventory.items, inventory.slots, hoveredSlot, w, h, draggingItem.item.slot, draggingItem.inventory, inventoryId);
    const isInFootprint = res.slots.includes(item.slot);

    return { inFootprint: isInFootprint, isFootprintBlocked: res.isBlocked };
  }, [hoveredSlot, hoveredInventory, inventory, draggingItem, inventoryId, item.slot]);

  useNuiEvent('refreshSlots', (data: { items?: ItemsPayload | ItemsPayload[] }) => {
    if (!isDragging && !data.items) return;
    if (!Array.isArray(data.items)) return;

    const itemSlot = data.items.find(
      (dataItem) => dataItem.item.slot === item.slot && dataItem.inventory === inventoryId
    );

    if (!itemSlot) return;

    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  const connectRef = (element: HTMLDivElement | null) => {
    if (!element) return;
    drag(drop(element));
  };

  const handleContext = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();
    if (inventoryType !== 'player' || !isSlotWithItem(item)) return;

    dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
  };

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    dispatch(closeTooltip());
    if (timerRef.current) clearTimeout(timerRef.current);
    if (event.ctrlKey && isSlotWithItem(item) && inventoryType !== 'shop' && inventoryType !== 'crafting') {
      onDrop({ item: item, inventory: inventoryType });
    } else if (event.altKey && isSlotWithItem(item) && inventoryType === 'player') {
      onUse(item);
    }
  };

  const refs = useMergeRefs([connectRef, ref]);

  return (
    <div
      ref={refs}
      onContextMenu={handleContext}
      onClick={handleClick}
      onMouseLeave={() => {
        if (hoveredSlot === item.slot && hoveredInventory === inventoryId) {
          setHoveredSlot(null, null);
        }
      }}
      className="inventory-slot"
      style={{
        filter:
          !canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) || !canCraftItem(item, inventoryType)
            ? 'brightness(80%) grayscale(100%)'
            : undefined,
        opacity: isDragging ? 0.4 : 1.0,
        backgroundImage: `url(${item?.name ? getItemUrl(item as SlotWithItem) : 'none'}`,
        border: inFootprint
          ? isFootprintBlocked
            ? '2px solid #ff1f3d !important'
            : '2px solid rgba(236, 233, 231, 0.65) !important'
          : isOver
            ? '1px dashed rgba(255,255,255,0.4)'
            : '',
        backgroundColor: inFootprint
          ? isFootprintBlocked
            ? 'rgba(255, 31, 61, 0.45) !important'
            : 'rgba(236, 233, 231, 0.12) !important'
          : undefined,
        gridColumnStart: (item.slot - 1) % 5 + 1,
        gridRowStart: Math.floor((item.slot - 1) / 5) + 1,
        gridColumn: `span ${(() => {
          let w = ((item as any)?.size?.width) || ((item as any)?.size?.[0]) || 1;
          let h = ((item as any)?.size?.height) || ((item as any)?.size?.[1]) || 1;
          if (item?.metadata?.rotated) return h;
          return w;
        })()}`,
        gridRow: `span ${(() => {
          let w = ((item as any)?.size?.width) || ((item as any)?.size?.[0]) || 1;
          let h = ((item as any)?.size?.height) || ((item as any)?.size?.[1]) || 1;
          if (item?.metadata?.rotated) return w;
          return h;
        })()}`,
      }}
    >
      {isSlotWithItem(item) && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={() => {
            timerRef.current = window.setTimeout(() => {
              dispatch(openTooltip({ item, inventoryType }));
            }, 500) as unknown as number;
          }}
          onMouseLeave={() => {
            dispatch(closeTooltip());
            if (timerRef.current) {
              clearTimeout(timerRef.current);
              timerRef.current = null;
            }
          }}
        >
          <div className="item-slot-header-wrapper">
            <div className="item-slot-info-wrapper">
              <p>
                {item.weight > 0
                  ? item.weight >= 1000
                    ? `${(item.weight / 1000).toLocaleString('en-us', {
                      minimumFractionDigits: 2,
                    })}kg `
                    : `${item.weight.toLocaleString('en-us', {
                      minimumFractionDigits: 0,
                    })}g `
                  : ''}
              </p>
              <p>{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
            </div>
          </div>
          <div>
            {inventoryType !== 'shop' && item?.durability !== undefined && (
              <WeightBar percent={item.durability} durability />
            )}
            {inventoryType === 'shop' && item?.price !== undefined && (
              <>
                {item?.currency !== 'money' && item.currency !== 'black_money' && item.price > 0 && item.currency ? (
                  <div className="item-slot-currency-wrapper">
                    <img
                      src={item.currency ? getItemUrl(item.currency) : 'none'}
                      alt="item-image"
                      style={{
                        imageRendering: '-webkit-optimize-contrast',
                        height: 'auto',
                        width: '2vh',
                        backfaceVisibility: 'hidden',
                        transform: 'translateZ(0)',
                      }}
                    />
                    <p>{item.price.toLocaleString('en-us')}</p>
                  </div>
                ) : (
                  <>
                    {item.price > 0 && (
                      <div
                        className="item-slot-price-wrapper"
                        style={{ color: item.currency === 'money' || !item.currency ? '#2ECC71' : '#E74C3C' }}
                      >
                        <p>
                          {Locale.$ || '$'}
                          {item.price.toLocaleString('en-us')}
                        </p>
                      </div>
                    )}
                  </>
                )}
              </>
            )}
            <div className="inventory-slot-label-box">
              <div className="inventory-slot-label-text">
                {item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));
