import { useRef } from 'react';
import styled from 'styled-components';
import Select from 'react-select';
import { T } from '../../../styles/global';

interface SelectInputProps {
  title: string;
  items: string[];
  defaultValue: string;
  clientValue: string;
  onChange: (value: string) => void;
}

const Container = styled.div`
  min-width: 0;

  display: flex;
  flex-direction: column;
  flex-grow: 1;

  > span {
    width: 100%;

    display: flex;
    justify-content: space-between;
    font-weight: 200;
  }
`;

const customStyles: any = {
  control: (styles: any) => ({
    ...styles,
    marginTop: '8px',
    background: T.field,
    fontSize: '13px',
    color: T.text,
    border: `1px solid ${T.edge}`,
    outline: 'none',
    boxShadow: 'none',
    '&:hover': { borderColor: T.red },
  }),
  placeholder: (styles: any) => ({ ...styles, fontSize: '13px', color: T.faint }),
  input: (styles: any) => ({ ...styles, fontSize: '13px', color: T.text }),
  singleValue: (styles: any) => ({
    ...styles,
    fontSize: '13px',
    color: T.text,
    border: 'none',
    outline: 'none',
  }),
  indicatorContainer: (styles: any) => ({ ...styles, borderColor: T.faint, color: T.faint }),
  dropdownIndicator: (styles: any) => ({ ...styles, borderColor: T.faint, color: T.faint }),
  indicatorSeparator: (styles: any) => ({ ...styles, background: T.edge }),
  menuPortal: (styles: any) => ({ ...styles, color: T.text, zIndex: 9999 }),
  menu: (styles: any) => ({
    ...styles,
    background: T.panel,
    border: `1px solid ${T.edge}`,
    position: 'absolute',
    marginBottom: '10px',
    borderRadius: '4px',
  }),
  menuList: (styles: any) => ({
    ...styles,
    background: T.panel,
    borderRadius: '4px',
    '&::-webkit-scrollbar': { width: '6px' },
    '&::-webkit-scrollbar-track': { background: 'none' },
    '&::-webkit-scrollbar-thumb': { borderRadius: '3px', background: T.edge },
  }),
  option: (styles: any, { isFocused, isSelected }: any) => ({
    ...styles,
    fontSize: '13px',
    borderRadius: '3px',
    width: '97%',
    marginLeft: 'auto',
    marginRight: 'auto',
    color: T.text,
    background: isSelected ? T.red : isFocused ? T.redSoft : 'none',
  }),
};

const SelectInput = ({ title, items, defaultValue, clientValue, onChange }: SelectInputProps) => {
  const selectRef = useRef<any>(null);

  const handleChange = (event: any, { action }: any): void => {
    if (action === 'select-option') {
      onChange(event.value);
    }
  };

  return (
    <Container>
      <span>
        <small>{title}</small>
        <small>{clientValue}</small>
      </span>
      <Select
        ref={selectRef}
        styles={customStyles}
        options={items.map(item => ({ value: item, label: item }))}
        value={{ value: defaultValue, label: defaultValue }}
        onChange={handleChange}
        menuPortalTarget={document.body}
      />
    </Container>
  );
};

export default SelectInput;
