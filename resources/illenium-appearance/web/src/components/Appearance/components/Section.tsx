import { useState, useEffect, useRef, ReactNode } from 'react';
import styled from 'styled-components';
import { FiChevronDown, FiChevronUp } from '../../../icons';
import { useSpring, animated } from 'react-spring';
import { T } from '../../../styles/global';

interface SectionProps {
  title: string;
  deps?: any[];
  children?: ReactNode;
}

interface HeaderProps {
  active: boolean;
}

const Container = styled.div`
  width: 100%;
  display: flex;
  flex-direction: column;
  color: ${T.text};
  user-select: none;

  & + div {
    margin-top: 8px;
  }
`;

const Header = styled.div<HeaderProps>`
  width: 100%;
  height: 40px;

  display: flex;
  align-items: center;
  justify-content: space-between;

  padding: 0 12px;
  border-radius: 4px;
  border: 1px solid ${T.edge};
  border-left: 2px solid ${({ active }) => (active ? T.red : 'transparent')};

  z-index: 2;

  background: ${({ active }) => (active ? T.redSoft : T.panel)};
  transition: background 0.12s, border-color 0.12s;

  &:hover {
    background: ${T.redSoft};
    border-left-color: ${T.red};
    cursor: pointer;
  }

  span {
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.02em;
  }

  svg {
    color: ${({ active }) => (active ? T.red : T.faint)};
  }
`;

const Items = styled.div`
  padding: 0 2px 5px 2px;
  overflow: hidden;
`;

const Section: React.FC<SectionProps> = ({ children, title, deps = [] }) => {
  const [active, setActive] = useState(false);

  const [height, setHeight] = useState(0);
  const ref = useRef<HTMLDivElement>(null);

  const props = useSpring({
    height: active ? height : 0,
    opacity: active ? 1 : 0,
  });

  useEffect(() => {
    if (ref.current) {
      setHeight(ref.current.offsetHeight);
    }
  }, [ref, setHeight]);

  useEffect(() => {
    if (ref.current) {
      setHeight(ref.current.offsetHeight);
    }
  }, [ref, setHeight, deps]);

  return (
    <Container>
      <Header active={active} onClick={() => setActive(state => !state)}>
        <span>{title}</span>
        {active ? <FiChevronUp size={18} /> : <FiChevronDown size={18} />}
      </Header>

      <animated.div style={{ ...props, overflow: 'hidden' }}>
        <Items ref={ref}>{children}</Items>
      </animated.div>
    </Container>
  );
};

export default Section;
