import { useEffect, useRef } from 'react';
import { noop } from '../utils/misc';
import { fetchNui } from '../utils/fetchNui';
import { closeTooltip } from '../store/tooltip';
import { useAppDispatch } from '../store';
import { closeContextMenu } from '../store/contextMenu';

type FrameVisibleSetter = (bool: boolean) => void;

const LISTENED_KEYS = ['Escape', 'Tab'];

// Basic hook to listen for key presses in NUI in order to exit
export const useExitListener = (visibleSetter: FrameVisibleSetter, visible: boolean) => {
  const setterRef = useRef<FrameVisibleSetter>(noop);
  const dispatch = useAppDispatch();
  const openTimeRef = useRef<number>(0);

  useEffect(() => {
    setterRef.current = visibleSetter;
  }, [visibleSetter]);

  useEffect(() => {
    if (visible) {
      openTimeRef.current = Date.now();
    }
  }, [visible]);

  useEffect(() => {
    const keyHandler = (e: KeyboardEvent) => {
      if (LISTENED_KEYS.includes(e.code)) {
        if (e.code === 'Tab' && Date.now() - openTimeRef.current < 250) {
          return;
        }
        setterRef.current(false);
        dispatch(closeTooltip());
        dispatch(closeContextMenu());
        fetchNui('exit');
      }
    };

    window.addEventListener('keyup', keyHandler);

    return () => window.removeEventListener('keyup', keyHandler);
  }, []);
};
