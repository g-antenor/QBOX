import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';

import { Items } from '../../store/items';
import { Slot } from '../../typings';

const PAGE_SIZE = 30;

const getReservedSlots = (items: Slot[]) => {
  const reserved = new Set<number>();
  for (const item of items) {
    if (item && item.name) {
      const itemData = Items[item.name];
      const size = item.size || (itemData as any)?.size;
      if (size) {
        let width = 1;
        let height = 1;
        if (typeof size === 'object' && !Array.isArray(size)) {
          width = size.width || 1;
          height = size.height || 1;
        } else if (Array.isArray(size)) {
          width = size[0] || 1;
          height = size[1] || 1;
        }
        const isRotated = item?.metadata?.rotated;
        if (isRotated) {
          const temp = width;
          width = height;
          height = temp;
        }
        if (width > 1 || height > 1) {
          const col = (item.slot - 1) % 5;
          if (col + width <= 5) {
            for (let r = 0; r < height; r++) {
              for (let c = 0; c < width; c++) {
                const slotIdx = item.slot + (r * 5) + c;
                if (slotIdx !== item.slot) {
                  reserved.add(slotIdx);
                }
              }
            }
          }
        }
      }
    }
  }
  return reserved;
};

const CircularWeight: React.FC<{ weight: number; maxWeight: number }> = ({ weight, maxWeight }) => {
  const percent = maxWeight ? Math.min((weight / maxWeight) * 100, 100) : 0;
  
  const color = (() => {
    if (percent < 35) return '#3ddc84'; // green
    if (percent < 65) return '#fcd34d'; // yellow
    if (percent < 85) return '#f97316'; // orange
    return '#ef4444'; // red
  })();

  const radius = 18;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (percent / 100) * circumference;

  return (
    <div className="circular-weight-container">
      <svg width="46" height="46" style={{ transform: 'rotate(-90deg)' }}>
        <circle
          cx="23"
          cy="23"
          r={radius}
          fill="transparent"
          stroke="rgba(255,255,255,0.06)"
          strokeWidth="3"
        />
        <circle
          cx="23"
          cy="23"
          r={radius}
          fill="transparent"
          stroke={color}
          strokeWidth="3.5"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.35s' }}
        />
      </svg>
      <div className="circular-weight-text">
        {(weight / 1000).toFixed(1)}
      </div>
    </div>
  );
};

const InventoryGrid: React.FC<{ inventory: Inventory }> = ({ inventory }) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  const reservedSlots = useMemo(() => getReservedSlots(inventory.items), [inventory.items]);

  return (
    <>
      <div className="inventory-grid-wrapper" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
        <div>
          <div className="inventory-header-container">
            <div className="inventory-title-section">
              <h1 className="inventory-title">{inventory.label}</h1>
            </div>
            {inventory.maxWeight && (
              <CircularWeight weight={weight} maxWeight={inventory.maxWeight} />
            )}
          </div>
        </div>
        <div className="inventory-grid-container" ref={containerRef}>
          <>
            {inventory.items.slice(0, (page + 1) * PAGE_SIZE).map((item, index) => {
              if (reservedSlots.has(item.slot)) {
                return null;
              }
              return (
                <InventorySlot
                  key={`${inventory.type}-${inventory.id}-${item.slot}`}
                  item={item}
                  ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
                  inventoryType={inventory.type}
                  inventoryGroups={inventory.groups}
                  inventoryId={inventory.id}
                />
              );
            })}
          </>
        </div>
      </div>
    </>
  );
};

export default InventoryGrid;
