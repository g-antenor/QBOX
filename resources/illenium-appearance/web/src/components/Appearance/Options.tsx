import { useState, ReactNode } from 'react';
import styled from 'styled-components';
import {
  FaVideo,
  FaStreetView,
  FaUndo,
  FaRedo,
  FaSmile,
  FaMale,
  FaShoePrints,
  FaSave,
  FaTimes,
  FaTshirt,
  FaHatCowboy,
  FaSocks,
  FaWalking,
  FaRunning,
  FaHandPaper,
  FaRegStopCircle,
} from '../../icons';

import { CameraState, ClothesState, CustomizationConfig, RotateState } from './interfaces';
import { T } from '../../styles/global';

export type AnimationKey = 'static' | 'walk' | 'run' | 'wave';

interface OptionsProps {
  camera: CameraState;
  rotate: RotateState;
  clothes: ClothesState;
  config: CustomizationConfig;
  animation: AnimationKey | null;
  handleSetClothes: (key: keyof ClothesState) => void;
  handleSetCamera: (key: keyof CameraState) => void;
  handleResetCamera: () => void;
  handleTurnAround: () => void;
  handleRotateLeft: () => void;
  handleRotateRight: () => void;
  handlePlayAnimation: (key: AnimationKey) => void;
  handleSave: () => void;
  handleExit: () => void;
}

const Panel = styled.div`
  height: 100vh;
  width: 260px;
  flex: none;

  display: flex;
  flex-direction: column;
  gap: 14px;

  padding: 24px 16px;

  background: ${T.panel};
  border-left: 1px solid ${T.edge};
`;

const Title = styled.div`
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: ${T.text};
  display: flex;
  align-items: center;
  gap: 7px;

  &::before {
    content: '';
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: ${T.red};
    box-shadow: 0 0 6px ${T.red};
  }
`;

const SubTabBar = styled.div`
  display: flex;
  gap: 4px;
  padding: 4px;
  border-radius: 4px;
  border: 1px solid ${T.edge};
  background: ${T.field};
`;

const SubTab = styled.button<{ active: boolean }>`
  flex: 1;
  padding: 7px 4px;
  border: 0;
  border-radius: 3px;
  background: ${({ active }) => (active ? T.red : 'transparent')};
  color: ${({ active }) => (active ? '#fff' : T.dim)};
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;

  &:hover {
    color: ${({ active }) => (active ? '#fff' : T.text)};
    background: ${({ active }) => (active ? T.redHover : T.redSoft)};
  }
`;

const Content = styled.div`
  flex: 1;
  min-height: 0;
  overflow-y: auto;

  display: flex;
  flex-direction: column;
  gap: 16px;
`;

const Group = styled.div`
  display: flex;
  flex-direction: column;
  gap: 8px;

  .label {
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: ${T.faint};
  }
  .row {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
`;

const Ctrl = styled.button<{ active?: boolean; wide?: boolean }>`
  height: 38px;
  flex: ${({ wide }) => (wide ? '1 1 100%' : '1')};
  min-width: 38px;

  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;

  border: 1px solid ${({ active }) => (active ? T.red : T.edge)};
  border-radius: 4px;

  color: ${({ active }) => (active ? '#fff' : T.dim)};
  background: ${({ active }) => (active ? T.red : T.field)};

  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  transition: all 0.12s;

  &:hover {
    color: #fff;
    border-color: ${T.red};
    background: ${({ active }) => (active ? T.redHover : T.redSoft)};
  }
  &:active { transform: scale(0.96); }
`;

const Footer = styled.div`
  display: flex;
  flex-direction: column;
  gap: 8px;
`;

const ActionBtn = styled.button<{ variant?: 'primary' | 'danger' }>`
  height: 40px;
  width: 100%;

  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;

  border-radius: 4px;
  border: 1px solid ${({ variant }) => (variant === 'primary' ? T.red : T.edge)};
  background: ${({ variant }) => (variant === 'primary' ? T.red : 'transparent')};
  color: ${({ variant }) => (variant === 'primary' ? '#fff' : T.dim)};

  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  transition: all 0.12s;

  &:hover {
    color: #fff;
    background: ${({ variant }) => (variant === 'primary' ? T.redHover : T.redSoft)};
    border-color: ${T.red};
  }
`;

const CtrlOption: React.FC<{
  active?: boolean;
  wide?: boolean;
  onClick: () => void;
  children?: ReactNode;
}> = ({ active, wide, onClick, children }) => (
  <Ctrl type="button" active={active} wide={wide} onClick={onClick}>
    {children}
  </Ctrl>
);

const Options: React.FC<OptionsProps> = ({
  camera,
  rotate,
  clothes,
  config,
  animation,
  handleSetClothes,
  handleSetCamera,
  handleResetCamera,
  handleTurnAround,
  handleRotateLeft,
  handleRotateRight,
  handlePlayAnimation,
  handleExit,
  handleSave,
}) => {
  const [tab, setTab] = useState<'camera' | 'animation'>('camera');

  return (
    <Panel>
      <Title>Controles</Title>

      <SubTabBar>
        <SubTab active={tab === 'camera'} onClick={() => setTab('camera')}>
          Câmera
        </SubTab>
        <SubTab active={tab === 'animation'} onClick={() => setTab('animation')}>
          Animação
        </SubTab>
      </SubTabBar>

      <Content>
        {tab === 'camera' ? (
          <>
            <Group>
              <span className="label">Enquadramento</span>
              <div className="row">
                <CtrlOption active={!camera.head && !camera.body && !camera.bottom} onClick={handleResetCamera}>
                  <FaVideo size={15} />
                </CtrlOption>
                <CtrlOption active={camera.head} onClick={() => handleSetCamera('head')}>
                  <FaSmile size={15} />
                </CtrlOption>
                <CtrlOption active={camera.body} onClick={() => handleSetCamera('body')}>
                  <FaMale size={15} />
                </CtrlOption>
                <CtrlOption active={camera.bottom} onClick={() => handleSetCamera('bottom')}>
                  <FaShoePrints size={15} />
                </CtrlOption>
              </div>
            </Group>

            <Group>
              <span className="label">Rotação</span>
              <div className="row">
                <CtrlOption active={rotate.left} onClick={handleRotateLeft}>
                  <FaRedo size={14} />
                </CtrlOption>
                <CtrlOption onClick={handleTurnAround}>
                  <FaStreetView size={15} />
                </CtrlOption>
                <CtrlOption active={rotate.right} onClick={handleRotateRight}>
                  <FaUndo size={14} />
                </CtrlOption>
              </div>
            </Group>

            <Group>
              <span className="label">Visibilidade das roupas</span>
              <div className="row">
                <CtrlOption active={!clothes.head} onClick={() => handleSetClothes('head')}>
                  <FaHatCowboy size={14} />
                </CtrlOption>
                <CtrlOption active={!clothes.body} onClick={() => handleSetClothes('body')}>
                  <FaTshirt size={14} />
                </CtrlOption>
                <CtrlOption active={!clothes.bottom} onClick={() => handleSetClothes('bottom')}>
                  <FaSocks size={14} />
                </CtrlOption>
              </div>
            </Group>
          </>
        ) : (
          <Group>
            <span className="label">Pose do personagem</span>
            <div className="row">
              <CtrlOption wide active={animation === 'static'} onClick={() => handlePlayAnimation('static')}>
                <FaRegStopCircle size={15} /> Estático
              </CtrlOption>
              <CtrlOption wide active={animation === 'wave'} onClick={() => handlePlayAnimation('wave')}>
                <FaHandPaper size={15} /> Levantar a mão
              </CtrlOption>
              <CtrlOption wide active={animation === 'walk'} onClick={() => handlePlayAnimation('walk')}>
                <FaWalking size={15} /> Andar
              </CtrlOption>
              <CtrlOption wide active={animation === 'run'} onClick={() => handlePlayAnimation('run')}>
                <FaRunning size={15} /> Correr
              </CtrlOption>
            </div>
          </Group>
        )}
      </Content>

      <Footer>
        <ActionBtn variant="primary" onClick={handleSave}>
          <FaSave size={14} /> Salvar
        </ActionBtn>
        {config.allowExit && (
          <ActionBtn variant="danger" onClick={handleExit}>
            <FaTimes size={14} /> Sair
          </ActionBtn>
        )}
      </Footer>
    </Panel>
  );
};

export default Options;
