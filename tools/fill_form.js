// Fill the Lab 5 submission form (document.xml) with info, screenshots and links
const fs = require('fs');
const dir = process.argv[2];
let doc = fs.readFileSync(dir + '/word/document.xml', 'utf8');
let rels = fs.readFileSync(dir + '/word/_rels/document.xml.rels', 'utf8');
let ct = fs.readFileSync(dir + '/[Content_Types].xml', 'utf8');
const EMU = 914400;
const imgs = [ // [paraId to fill, file, pixel w, pixel h, alt]
  ['00000009', 'image1.png', 1936, 1048, 'Godot editor - Level 1'],
  ['0000000C', 'image2.png', 1936, 1048, 'Godot editor - Level 2'],
  ['0000000F', 'image3.png', 1936, 1048, 'Godot editor - Player'],
  ['00000014', 'image4.png', 1280, 720, 'Gameplay - Level 1'],
  ['00000017', 'image5.png', 1280, 720, 'Gameplay - Level 2'],
];
const PLAY = 'https://super-super-dev.github.io/lab5_prod/';
const SRC = 'https://github.com/super-SuPer-dev/lab5_editor';
const PROD = 'https://github.com/super-SuPer-dev/lab5_prod';
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const paraRe = id => new RegExp('<w:p [^>]*w14:paraId="' + id + '"[^>]*>[^]*?</w:p>');
const pPr = '<w:pPr><w:ind w:left="720" w:firstLine="0"/><w:jc w:val="center"/><w:rPr/></w:pPr>';
let rid = 100;
imgs.forEach(([pid, file, w, h, alt], i) => {
  const id = 'rId' + (rid++);
  rels = rels.replace('</Relationships>', `<Relationship Id="${id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${file}"/></Relationships>`);
  const cx = Math.round(6.4 * EMU), cy = Math.round(6.4 * EMU * h / w);
  const drawing = `<w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="${cx}" cy="${cy}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="${i + 1}" name="Picture ${i + 1}" descr="${esc(alt)}"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="${i + 1}" name="${file}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${id}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${cx}" cy="${cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>`;
  const re = paraRe(pid);
  if (!re.test(doc)) throw new Error('para not found ' + pid);
  doc = doc.replace(re, m => m.replace(/<w:pPr>[\s\S]*?<\/w:pPr>/, pPr).replace(/<w:r [\s\S]*<\/w:r>/, drawing));
});
const link = (url, text) => {
  const id = 'rId' + (rid++);
  rels = rels.replace('</Relationships>', `<Relationship Id="${id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${esc(url)}" TargetMode="External"/></Relationships>`);
  return `<w:hyperlink r:id="${id}"><w:r><w:rPr><w:color w:val="1155CC"/><w:u w:val="single"/></w:rPr><w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:hyperlink>`;
};
const plain = t => `<w:r><w:t xml:space="preserve">${esc(t)}</w:t></w:r>`;
const br = '<w:r><w:br/></w:r>';
const fillPara = (pid, inner) => { doc = doc.replace(paraRe(pid), m => m.replace(/<w:r [\s\S]*<\/w:r>/, inner)); };
fillPara('0000001B', link(PLAY, PLAY));
fillPara('0000001D', plain('Source (GitHub): ') + link(SRC, SRC) + br + plain('Web build (GitHub): ') + link(PROD, PROD));
// student info line
doc = doc.replace(/<w:t xml:space="preserve">รหัส:<\/w:t><w:tab\/><w:tab\/><w:t xml:space="preserve">ชื่อ-สกุล: <\/w:t><w:tab\/><w:t xml:space="preserve">       <\/w:t><w:tab\/><w:t xml:space="preserve">กลุ่มเรียน:<\/w:t>/,
  '<w:t xml:space="preserve">รหัส: 673380335</w:t><w:tab/><w:t xml:space="preserve">ชื่อ-สกุล: Pudtipong Panichpun</w:t><w:tab/><w:t xml:space="preserve">กลุ่มเรียน: 3</w:t>');
if (!doc.includes('673380335')) throw new Error('student line not replaced');
if (!ct.includes('Extension="png"')) ct = ct.replace('<Default ContentType="application/xml" Extension="xml"/>', '<Default ContentType="application/xml" Extension="xml"/><Default ContentType="image/png" Extension="png"/>');
fs.writeFileSync(dir + '/word/document.xml', doc);
fs.writeFileSync(dir + '/word/_rels/document.xml.rels', rels);
fs.writeFileSync(dir + '/[Content_Types].xml', ct);
console.log('ok', doc.length);
