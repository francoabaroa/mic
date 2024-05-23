use docx_rs::*;
use pdf_extract::extract_text;
use rustler::{Atom, NifResult};
use std::fs::File;
use std::io::Read;

rustler::init!(
    "Elixir.Mic.Chat.DocumentParser",
    [parse_docx, parse_pdf, parse_txt]
);

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

#[rustler::nif]
fn parse_docx(file_path: String) -> NifResult<(Atom, String)> {
    let mut file =
        File::open(&file_path).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let mut buf = vec![];
    file.read_to_end(&mut buf)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let docx = read_docx(&buf).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let mut text = String::new();

    for child in docx.document.children {
        if let DocumentChild::Paragraph(paragraph) = child {
            for para_child in paragraph.children {
                if let ParagraphChild::Run(run) = para_child {
                    for run_child in run.children {
                        if let RunChild::Text(text_element) = run_child {
                            text.push_str(&text_element.text);
                        }
                    }
                }
            }
        }
    }

    Ok((atoms::ok(), text))
}

#[rustler::nif]
fn parse_pdf(file_path: String) -> NifResult<(Atom, String)> {
    let text =
        extract_text(&file_path).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    Ok((atoms::ok(), text))
}

#[rustler::nif]
fn parse_txt(file_path: String) -> NifResult<(Atom, String)> {
    let mut file =
        File::open(file_path).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let mut text = String::new();
    file.read_to_string(&mut text)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    Ok((atoms::ok(), text))
}
