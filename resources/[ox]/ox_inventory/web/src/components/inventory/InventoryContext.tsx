import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { onDrop } from '../../dnd/onDrop';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { isSlotWithItem } from '../../helpers';
import { setClipboard } from '../../utils/setClipboard';
import { useAppSelector } from '../../store';
import React, { useState } from 'react';
import { Menu, MenuItem } from '../utils/menu/Menu';
import { FloatingPortal } from '@floating-ui/react';

interface DataProps {
  action: string;
  component?: string;
  slot?: number;
  serial?: string;
  id?: number;
}

interface Button {
  label: string;
  index: number;
  group?: string;
}

interface Group {
  groupName: string | null;
  buttons: ButtonWithIndex[];
}

interface ButtonWithIndex extends Button {
  index: number;
}

interface GroupedButtons extends Array<Group> {}

const InventoryContext: React.FC = () => {
  const contextMenu = useAppSelector((state) => state.contextMenu);
  const item = contextMenu.item;

  const [showSplitModal, setShowSplitModal] = useState(false);
  const [splitCount, setSplitCount] = useState(1);

  const handleClick = (data: DataProps) => {
    if (!item) return;

    switch (data && data.action) {
      case 'use':
        onUse({ name: item.name, slot: item.slot });
        break;
      case 'give':
        onGive({ name: item.name, slot: item.slot });
        break;
      case 'drop':
        isSlotWithItem(item) && onDrop({ item: item, inventory: 'player' });
        break;
      case 'split':
        setSplitCount(1);
        setShowSplitModal(true);
        break;
      case 'remove':
        fetchNui('removeComponent', { component: data?.component, slot: data?.slot });
        break;
      case 'removeAmmo':
        fetchNui('removeAmmo', item.slot);
        break;
      case 'copy':
        setClipboard(data.serial || '');
        break;
      case 'custom':
        fetchNui('useButton', { id: (data?.id || 0) + 1, slot: item.slot });
        break;
    }
  };

  const groupButtons = (buttons: any): GroupedButtons => {
    return buttons.reduce((groups: Group[], button: Button, index: number) => {
      if (button.group) {
        const groupIndex = groups.findIndex((group) => group.groupName === button.group);
        if (groupIndex !== -1) {
          groups[groupIndex].buttons.push({ ...button, index });
        } else {
          groups.push({
            groupName: button.group,
            buttons: [{ ...button, index }],
          });
        }
      } else {
        groups.push({
          groupName: null,
          buttons: [{ ...button, index }],
        });
      }
      return groups;
    }, []);
  };

  return (
    <>
      <Menu>
        <MenuItem onClick={() => handleClick({ action: 'use' })} label="Usar" />
        <MenuItem onClick={() => handleClick({ action: 'give' })} label="entregar" />
        <MenuItem onClick={() => handleClick({ action: 'split' })} label="Separar" />
        {item && item.metadata?.ammo > 0 && (
          <MenuItem onClick={() => handleClick({ action: 'removeAmmo' })} label={Locale.ui_remove_ammo} />
        )}
        {item && item.metadata?.serial && (
          <MenuItem
            onClick={() => handleClick({ action: 'copy', serial: item.metadata?.serial })}
            label={Locale.ui_copy}
          />
        )}
        {item && item.metadata?.components && item.metadata?.components.length > 0 && (
          <Menu label={Locale.ui_removeattachments}>
            {item &&
              item.metadata?.components.map((component: string, index: number) => (
                <MenuItem
                  key={index}
                  onClick={() => handleClick({ action: 'remove', component, slot: item.slot })}
                  label={Items[component]?.label || ''}
                />
              ))}
          </Menu>
        )}
        {((item && item.name && Items[item.name]?.buttons?.length) || 0) > 0 && (
          <>
            {item &&
              item.name &&
              groupButtons(Items[item.name]?.buttons).map((group: Group, index: number) => (
                <React.Fragment key={index}>
                  {group.groupName ? (
                    <Menu label={group.groupName}>
                      {group.buttons.map((button: Button) => (
                        <MenuItem
                          key={button.index}
                          onClick={() => handleClick({ action: 'custom', id: button.index })}
                          label={button.label}
                        />
                      ))}
                    </Menu>
                  ) : (
                    group.buttons.map((button: Button) => (
                      <MenuItem
                        key={button.index}
                        onClick={() => handleClick({ action: 'custom', id: button.index })}
                        label={button.label}
                      />
                    ))
                  )}
                </React.Fragment>
              ))}
          </>
        )}
      </Menu>

      {showSplitModal && item && (
        <FloatingPortal>
          <div className="split-modal-backdrop">
            <div className="useful-controls-dialog split-modal-content">
              <div className="useful-controls-dialog-title split-modal-header">
                <p>Separar Item</p>
                <p className="split-modal-item-label">{Items[item.name]?.label || item.name}</p>
              </div>
              <div className="split-modal-body">
                <div className="split-slider-container">
                  <input
                    type="range"
                    min="1"
                    max={item.count}
                    value={splitCount}
                    onChange={(e) => setSplitCount(Number(e.target.value))}
                    className="split-slider"
                  />
                  <div className="split-value-display">
                    <input
                      type="number"
                      min="1"
                      max={item.count}
                      value={splitCount}
                      onChange={(e) => {
                        const val = Math.max(1, Math.min(item.count, Number(e.target.value) || 1));
                        setSplitCount(val);
                      }}
                      className="split-number-input"
                    />
                    <span>/ {item.count}</span>
                  </div>
                </div>
              </div>
              <div className="split-modal-footer">
                <button
                  className="split-btn split-btn-confirm"
                  onClick={() => {
                    fetchNui('splitItem', { slot: item.slot, count: splitCount });
                    setShowSplitModal(false);
                  }}
                >
                  Confirmar
                </button>
                <button
                  className="split-btn split-btn-cancel"
                  onClick={() => setShowSplitModal(false)}
                >
                  Cancelar
                </button>
              </div>
            </div>
          </div>
        </FloatingPortal>
      )}
    </>
  );
};

export default InventoryContext;
