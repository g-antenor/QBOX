import styled from 'styled-components';
import { ReactNode } from 'react';
import { T } from '../../../styles/global';

interface ItemProps {
  title?: string;
  children?: ReactNode;
}

const Container = styled.div`
  margin-top: 8px;

  display: flex;
  flex-direction: column;

  padding: 10px 12px;
  border-radius: 4px;
  border: 1px solid ${T.edge};

  background: ${T.field};

  > span {
    color: ${T.dim};
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.03em;
    text-transform: uppercase;
  }
`;

const Inputs = styled.div`
  width: 100%;
  display: inline-flex;
  flex-wrap: wrap;

  margin-top: 10px;

  > div {
    & + div {
      margin-top: 12px;
    }
  }
`;

const Item: React.FC<ItemProps> = ({ children, title }) => {
  return (
    <Container>
      {title && <span>{title}</span>}
      <Inputs>{children}</Inputs>
    </Container>
  );
};

export default Item;
